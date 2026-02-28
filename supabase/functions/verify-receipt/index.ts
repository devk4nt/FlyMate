import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface VerifyReceiptRequest {
  transactionId: string;
  originalTransactionId: string;
  productId: string;
  purchaseDate: string;
  expiresDate: string;
  environment: "production" | "sandbox";
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

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: VerifyReceiptRequest = await req.json();

    // 플랜 결정: product ID 기반
    let planId = "free";
    if (body.productId.includes("yearly")) {
      planId = "premium_yearly";
    } else if (body.productId.includes("monthly")) {
      planId = "premium_monthly";
    }

    // Admin 클라이언트로 subscriptions 테이블 업데이트
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    const { error: upsertError } = await supabaseAdmin
      .from("subscriptions")
      .upsert(
        {
          user_id: user.id,
          plan_id: planId,
          status: "active",
          original_transaction_id: body.originalTransactionId,
          latest_transaction_id: body.transactionId,
          product_id: body.productId,
          environment: body.environment,
          purchase_date: body.purchaseDate,
          expires_date: body.expiresDate,
          auto_renew_status: true,
        },
        { onConflict: "user_id" }
      );

    if (upsertError) {
      return new Response(JSON.stringify({ error: upsertError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 업데이트된 entitlements 반환
    const { data: entitlements, error: rpcError } = await supabaseAdmin.rpc(
      "get_user_entitlements",
      { p_user_id: user.id }
    );

    if (rpcError) {
      return new Response(JSON.stringify({ error: rpcError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify(entitlements), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
