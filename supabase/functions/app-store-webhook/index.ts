import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// App Store Server Notifications V2 타입
interface AppStoreNotification {
  notificationType: string;
  subtype?: string;
  data: {
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
    environment: string;
  };
}

interface TransactionInfo {
  originalTransactionId: string;
  transactionId: string;
  productId: string;
  purchaseDate: number;
  expiresDate: number;
  environment: string;
}

interface RenewalInfo {
  autoRenewStatus: number;
  expirationIntent?: number;
}

// JWS 페이로드 디코딩 (서명 검증 없이 페이로드만 추출)
function decodeJWSPayload<T>(jws: string): T {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWS format");
  const payload = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"));
  return JSON.parse(payload) as T;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const notification: AppStoreNotification = await req.json();
    const { notificationType, subtype } = notification;

    console.log(
      `[AppStore Webhook] type=${notificationType}, subtype=${subtype ?? "none"}`
    );

    // signedTransactionInfo 디코딩
    if (!notification.data.signedTransactionInfo) {
      return new Response(JSON.stringify({ message: "No transaction info" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const txnInfo = decodeJWSPayload<TransactionInfo>(
      notification.data.signedTransactionInfo
    );

    let renewalInfo: RenewalInfo | null = null;
    if (notification.data.signedRenewalInfo) {
      renewalInfo = decodeJWSPayload<RenewalInfo>(
        notification.data.signedRenewalInfo
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // original_transaction_id로 구독 레코드 조회
    const { data: subscription, error: fetchError } = await supabaseAdmin
      .from("subscriptions")
      .select("*")
      .eq("original_transaction_id", txnInfo.originalTransactionId)
      .maybeSingle();

    if (fetchError) {
      console.error("[AppStore Webhook] Fetch error:", fetchError.message);
      return new Response(JSON.stringify({ error: fetchError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!subscription) {
      console.warn(
        `[AppStore Webhook] No subscription found for original_transaction_id: ${txnInfo.originalTransactionId}`
      );
      return new Response(
        JSON.stringify({ message: "Subscription not found" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 알림 유형별 상태 업데이트
    let updateData: Record<string, unknown> = {
      latest_transaction_id: txnInfo.transactionId,
      expires_date: new Date(txnInfo.expiresDate).toISOString(),
    };

    if (renewalInfo) {
      updateData.auto_renew_status = renewalInfo.autoRenewStatus === 1;
    }

    switch (notificationType) {
      case "DID_RENEW":
        updateData.status = "active";
        updateData.is_in_billing_retry = false;
        updateData.purchase_date = new Date(
          txnInfo.purchaseDate
        ).toISOString();
        break;

      case "EXPIRED":
        if (subtype === "BILLING_RETRY") {
          updateData.status = "billing_retry";
          updateData.is_in_billing_retry = true;
        } else {
          updateData.status = "expired";
          updateData.plan_id = "free";
          updateData.is_in_billing_retry = false;
        }
        break;

      case "REVOKE":
        updateData.status = "revoked";
        updateData.plan_id = "free";
        break;

      case "REFUND":
        updateData.status = "revoked";
        updateData.plan_id = "free";
        break;

      case "GRACE_PERIOD_EXPIRED":
        updateData.status = "expired";
        updateData.plan_id = "free";
        updateData.is_in_billing_retry = false;
        break;

      case "DID_CHANGE_RENEWAL_STATUS":
        // 자동 갱신 상태만 업데이트 (이미 renewalInfo에서 처리)
        break;

      case "DID_CHANGE_RENEWAL_INFO":
        // 플랜 변경 (다운그레이드/업그레이드)
        if (txnInfo.productId.includes("yearly")) {
          updateData.product_id = txnInfo.productId;
          updateData.plan_id = "premium_yearly";
        } else if (txnInfo.productId.includes("monthly")) {
          updateData.product_id = txnInfo.productId;
          updateData.plan_id = "premium_monthly";
        }
        break;

      case "SUBSCRIBED":
      case "DID_RENEW":
        updateData.status = "active";
        updateData.is_in_billing_retry = false;
        break;

      default:
        console.log(
          `[AppStore Webhook] Unhandled notification type: ${notificationType}`
        );
    }

    const { error: updateError } = await supabaseAdmin
      .from("subscriptions")
      .update(updateData)
      .eq("id", subscription.id);

    if (updateError) {
      console.error("[AppStore Webhook] Update error:", updateError.message);
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(
      `[AppStore Webhook] Updated subscription ${subscription.id}: ${notificationType}`
    );

    return new Response(JSON.stringify({ message: "OK" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[AppStore Webhook] Error:", (err as Error).message);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
