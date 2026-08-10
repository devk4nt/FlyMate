import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface KakaoUserResponse {
  id: number;
  kakao_account?: {
    email?: string;
    profile?: {
      nickname?: string;
      profile_image_url?: string;
    };
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { access_token } = await req.json();
    if (!access_token) {
      return new Response(
        JSON.stringify({ error: "access_token is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Kakao API로 사용자 정보 조회
    const kakaoRes = await fetch("https://kapi.kakao.com/v2/user/me", {
      headers: { Authorization: `Bearer ${access_token}` },
    });

    if (!kakaoRes.ok) {
      return new Response(
        JSON.stringify({ error: "Invalid Kakao access token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const kakaoUser: KakaoUserResponse = await kakaoRes.json();
    const realEmail = kakaoUser.kakao_account?.email ?? null;
    const name = kakaoUser.kakao_account?.profile?.nickname ?? "User";

    // 이메일 동의항목은 비즈 앱 전환 후에만 쓸 수 있으므로, auth 식별자는
    // 카카오 회원번호 기반 내부용 이메일로 고정한다. 실제 이메일은 (동의받은
    // 경우에만) public.users.email에 반영 — 나중에 비즈 앱 승인이 나도
    // 같은 카카오 계정이 같은 유저로 유지된다.
    const authEmail = `kakao_${kakaoUser.id}@kakao.flymate.app`;

    // 2. Supabase Admin 클라이언트
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // 3. 사용자 생성 (이미 존재하면 무시)
    const { error: createError } = await supabaseAdmin.auth.admin.createUser({
      email: authEmail,
      email_confirm: true,
      user_metadata: { name, provider: "kakao" },
      app_metadata: { provider: "kakao" },
    });

    if (createError && !createError.message.includes("already been registered")) {
      return new Response(
        JSON.stringify({ error: createError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. 세션 생성 (magiclink + OTP 검증)
    const { data: linkData, error: linkError } =
      await supabaseAdmin.auth.admin.generateLink({
        type: "magiclink",
        email: authEmail,
      });

    if (linkError || !linkData.properties?.hashed_token) {
      return new Response(
        JSON.stringify({ error: linkError?.message ?? "Failed to generate session" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: sessionData, error: sessionError } =
      await supabaseAdmin.auth.verifyOtp({
        email: authEmail,
        token: linkData.properties.hashed_token,
        type: "email",
      });

    if (sessionError || !sessionData.session) {
      return new Response(
        JSON.stringify({ error: sessionError?.message ?? "Failed to create session" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 실제 이메일을 동의받은 경우 프로필에 반영 (best-effort)
    if (realEmail) {
      await supabaseAdmin
        .from("users")
        .update({ email: realEmail })
        .eq("id", sessionData.session.user.id);
    }

    return new Response(
      JSON.stringify({
        access_token: sessionData.session.access_token,
        refresh_token: sessionData.session.refresh_token,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
