import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Sign in with Apple 토큰 revoke (App Store 심사 요구사항 — 계정 삭제 시 필수)
// 필요한 secrets: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY(.p8 내용), APPLE_CLIENT_ID(번들 ID)
async function revokeAppleTokens(authorizationCode: string): Promise<void> {
  const teamID = Deno.env.get("APPLE_TEAM_ID");
  const keyID = Deno.env.get("APPLE_KEY_ID");
  const privateKeyPem = Deno.env.get("APPLE_PRIVATE_KEY");
  const clientID = Deno.env.get("APPLE_CLIENT_ID");
  if (!teamID || !keyID || !privateKeyPem || !clientID) {
    throw new Error("Apple revoke secrets not configured");
  }

  const base64 = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  const der = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const now = Math.floor(Date.now() / 1000);
  const clientSecret = await create(
    { alg: "ES256", kid: keyID },
    { iss: teamID, iat: now, exp: now + 300, aud: "https://appleid.apple.com", sub: clientID },
    key
  );

  // authorization code → refresh token 교환
  const tokenRes = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientID,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenRes.ok) {
    throw new Error(`Apple token exchange failed: ${tokenRes.status} ${await tokenRes.text()}`);
  }
  const { refresh_token } = await tokenRes.json();

  const revokeRes = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientID,
      client_secret: clientSecret,
      token: refresh_token,
      token_type_hint: "refresh_token",
    }),
  });
  if (!revokeRes.ok) {
    throw new Error(`Apple token revoke failed: ${revokeRes.status}`);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 요청자의 JWT에서 사용자 ID 추출
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Apple 계정: 클라이언트가 재인증으로 받아온 authorization code로 토큰 revoke
    let appleAuthorizationCode: string | null = null;
    try {
      const body = await req.json();
      appleAuthorizationCode = body?.apple_authorization_code ?? null;
    } catch {
      // body 없음 (카카오 계정 등) — 무시
    }
    if (appleAuthorizationCode) {
      try {
        await revokeAppleTokens(appleAuthorizationCode);
      } catch (e) {
        // ponytail: revoke 실패(코드 만료 등)가 탈퇴 자체를 막지 않도록 best-effort
        console.error("Apple token revoke failed:", (e as Error).message);
      }
    }

    // Admin 클라이언트로 사용자 삭제 (CASCADE로 관련 데이터 자동 삭제)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // 모든 스터디의 영상·피드백·댓글 삭제 + 남은 글의 멘션 '@탈퇴한사용자' 치환
    // 삭제된 영상의 (study_id, video_id)를 반환받아 Storage 파일 정리에 사용
    const { data: deletedVideos, error: removeError } = await supabaseAdmin.rpc(
      "remove_user_content_all_studies",
      { p_user_id: user.id }
    );
    if (removeError) {
      return new Response(
        JSON.stringify({ error: removeError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Storage 파일 정리 (영상, 썸네일, 프로필 이미지)
    const videoRows = (deletedVideos ?? []) as { study_id: string; video_id: string }[];
    if (videoRows.length > 0) {
      await supabaseAdmin.storage
        .from("videos")
        .remove(videoRows.map((r) => `${r.study_id}/${r.video_id}.mp4`));
      await supabaseAdmin.storage
        .from("thumbnails")
        .remove(videoRows.map((r) => `${r.study_id}/${r.video_id}.jpg`));
    }
    // iOS가 대문자 UUID 경로로 업로드하므로 두 케이스 모두 제거
    await supabaseAdmin.storage
      .from("profile-images")
      .remove([`${user.id}.jpg`, `${user.id.toUpperCase()}.jpg`]);

    // Auth 사용자 삭제 (users, study_members, notifications는 CASCADE 삭제)
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id);
    if (deleteError) {
      return new Response(
        JSON.stringify({ error: deleteError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ message: "Account deleted successfully" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
