# 영상 업로드 관리자 이메일 알림 설정

`videos`와 `quick_feedback_requests` 테이블에 새 행이 생성되면
`send-video-upload-email` Edge Function이 관리자에게 이메일을 보냅니다.

영상 버킷은 비공개이므로 이메일에는 영상 URL을 넣지 않습니다.

## 1. Resend 준비

### 빠른 테스트

1. `flymate.team.contact@gmail.com`으로 Resend에 가입합니다.
2. API Key를 `Sending access` 권한으로 생성합니다.
3. 테스트 발신 주소로 `FlyMate <onboarding@resend.dev>`를 사용합니다.

`resend.dev` 테스트 발신자는 Resend 계정에 등록된 본인 이메일로만 발송할 수 있습니다.
수신 주소와 Resend 가입 주소가 모두 `flymate.team.contact@gmail.com`이면 도메인 인증 없이
먼저 동작을 확인할 수 있습니다.

### 운영 전환

다른 주소에도 발송하거나 정식 발신 주소를 표시하려면 Resend에서 소유 도메인을
인증하고 `FlyMate <alerts@인증한-도메인>` 형태로 변경합니다.

## 2. Edge Function 시크릿 등록

아래 값에서 예시는 실제 값으로 바꿉니다. 웹훅 시크릿에는 충분히 긴 임의 문자열을 사용합니다.

```bash
supabase secrets set \
  RESEND_API_KEY=re_xxxxxxxxx \
  RESEND_FROM_EMAIL='FlyMate <onboarding@resend.dev>' \
  VIDEO_UPLOAD_WEBHOOK_SECRET=replace-with-a-long-random-secret
```

관리자 알림은 기본적으로 `flymate.team.contact@gmail.com`으로 발송됩니다. 다른 주소로
변경할 때만 `ADMIN_NOTIFICATION_EMAIL` 시크릿을 추가하면 됩니다.

`SUPABASE_URL`과 `SUPABASE_SERVICE_ROLE_KEY`은 호스팅된 Edge Function에 기본
제공되므로 별도로 등록하지 않습니다.

## 3. Edge Function 배포

함수 자체가 `x-webhook-secret`을 검사하므로 JWT 검증 없이 배포합니다.

```bash
supabase functions deploy send-video-upload-email --no-verify-jwt
```

## 4. Database Webhook 생성

Supabase Dashboard의 **Database > Webhooks**에서 아래 웹훅 두 개를 만듭니다.

### 일반 스터디 피드백 영상

- 이름: `email-on-video-upload`
- 테이블: `public.videos`
- 이벤트: `INSERT`
- 방식: Supabase Edge Function
- 함수: `send-video-upload-email`
- HTTP 헤더: `x-webhook-secret: <VIDEO_UPLOAD_WEBHOOK_SECRET과 같은 값>`

### 빠른 피드백 영상

- 이름: `email-on-quick-feedback-upload`
- 테이블: `public.quick_feedback_requests`
- 이벤트: `INSERT`
- 방식: Supabase Edge Function
- 함수: `send-video-upload-email`
- HTTP 헤더: `x-webhook-secret: <VIDEO_UPLOAD_WEBHOOK_SECRET과 같은 값>`

두 웹훅 모두 `Content-Type: application/json`을 유지합니다.

## 5. 확인

테스트 계정으로 일반 영상과 빠른 피드백 영상을 각각 한 번 등록합니다.

- 관리자 메일에 사용자, 스터디, 제목, 길이, 업로드 시각이 표시되는지 확인합니다.
- Edge Function Logs에서 응답이 `200`인지 확인합니다.
- 실패한 웹훅 호출은 Supabase의 `net` 스키마 로그에서 확인할 수 있습니다.

같은 테이블과 영상 ID로 웹훅이 재시도되더라도 Resend의 idempotency key로 24시간 동안
중복 메일 발송을 방지합니다.
