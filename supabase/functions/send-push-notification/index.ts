import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface WebhookPayload {
  type: "INSERT";
  table: string;
  record: {
    id: string;
    recipient_id: string;
    type: string;
    title: string;
    body: string;
    reference_video_id: string | null;
    reference_feedback_id: string | null;
    is_read: boolean;
    created_at: string;
  };
}

interface DeviceToken {
  fcm_token: string;
}

interface GoogleTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

/**
 * Base64url encode (RFC 4648 Section 5)
 */
function base64urlEncode(data: Uint8Array): string {
  const base64 = btoa(String.fromCharCode(...data));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * Create a JWT signed with RS256 using the service account private key.
 */
async function createSignedJwt(
  serviceAccount: { client_email: string; private_key: string; project_id: string }
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encoder = new TextEncoder();
  const headerB64 = base64urlEncode(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64urlEncode(encoder.encode(JSON.stringify(payload)));
  const unsignedToken = `${headerB64}.${payloadB64}`;

  // Import RSA private key
  const pemContents = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(unsignedToken)
  );

  const signatureB64 = base64urlEncode(new Uint8Array(signature));
  return `${unsignedToken}.${signatureB64}`;
}

/**
 * Get an OAuth2 access token for FCM using the service account.
 */
async function getAccessToken(
  serviceAccount: { client_email: string; private_key: string; project_id: string }
): Promise<string> {
  const jwt = await createSignedJwt(serviceAccount);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to get access token: ${error}`);
  }

  const data: GoogleTokenResponse = await response.json();
  return data.access_token;
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    // Only process INSERT events on notifications table
    if (payload.type !== "INSERT" || payload.table !== "notifications") {
      return new Response(JSON.stringify({ message: "Ignored" }), { status: 200 });
    }

    const notification = payload.record;

    // Create admin client to bypass RLS
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Fetch device tokens for the recipient
    const { data: tokens, error: tokenError } = await supabaseAdmin
      .from("device_tokens")
      .select("fcm_token")
      .eq("user_id", notification.recipient_id)
      .eq("notifications_enabled", true);

    if (tokenError) {
      console.error("Failed to fetch device tokens:", tokenError.message);
      return new Response(
        JSON.stringify({ error: tokenError.message }),
        { status: 500 }
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log(`No device tokens found for user ${notification.recipient_id}`);
      return new Response(
        JSON.stringify({ message: "No device tokens" }),
        { status: 200 }
      );
    }

    // Parse service account key and get OAuth2 access token
    const serviceAccountJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_KEY");
    if (!serviceAccountJson) {
      throw new Error("GOOGLE_SERVICE_ACCOUNT_KEY not configured");
    }
    const serviceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getAccessToken(serviceAccount);

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    // Build push data payload
    const pushData: Record<string, string> = {
      type: notification.type,
    };
    if (notification.reference_video_id) {
      pushData.videoId = notification.reference_video_id;
    }
    if (notification.reference_feedback_id) {
      pushData.feedbackId = notification.reference_feedback_id;
    }

    // Send push to each device token
    const results = await Promise.allSettled(
      (tokens as DeviceToken[]).map(async ({ fcm_token }) => {
        const response = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: fcm_token,
              notification: {
                title: notification.title,
                body: notification.body,
              },
              data: pushData,
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            },
          }),
        });

        if (!response.ok) {
          const errorBody = await response.json();
          const errorCode = errorBody?.error?.details?.[0]?.errorCode
            ?? errorBody?.error?.status;

          // Remove invalid/unregistered tokens
          if (
            errorCode === "UNREGISTERED" ||
            errorCode === "INVALID_ARGUMENT" ||
            response.status === 404
          ) {
            console.log(`Removing invalid token: ${fcm_token.substring(0, 10)}...`);
            await supabaseAdmin
              .from("device_tokens")
              .delete()
              .eq("fcm_token", fcm_token);
          }

          throw new Error(`FCM error for token ${fcm_token.substring(0, 10)}...: ${JSON.stringify(errorBody)}`);
        }

        return response.json();
      })
    );

    const succeeded = results.filter((r) => r.status === "fulfilled").length;
    const failed = results.filter((r) => r.status === "rejected").length;

    for (const result of results) {
      if (result.status === "rejected") {
        console.error("Push failed:", result.reason?.message ?? result.reason);
      }
    }

    console.log(`Push sent: ${succeeded} succeeded, ${failed} failed`);

    return new Response(
      JSON.stringify({ succeeded, failed }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("send-push-notification error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
