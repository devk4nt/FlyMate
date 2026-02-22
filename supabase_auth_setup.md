# FlyMate Auth Provider Setup

## 1. Apple Sign In

### Apple Developer Console

1. [Apple Developer](https://developer.apple.com) > Certificates, Identifiers & Profiles
2. **Identifiers** > App ID (`com.flymate.app`) > **Sign In with Apple** 활성화
3. **Keys** > 새 키 생성 > **Sign In with Apple** 체크
   - Key ID 기록
   - `.p8` 파일 다운로드 (재다운로드 불가, 안전하게 보관)
4. **Team ID** 기록 (우상단 계정 이름 옆)

### Supabase Dashboard

1. **Authentication** > **Providers** > **Apple** 활성화
2. 다음 값 입력:
   - **Secret Key**: `.p8` 파일 내용 전체 붙여넣기
   - **Key ID**: Apple에서 발급받은 Key ID
   - **Team ID**: Apple Developer Team ID
   - **Bundle ID**: `com.flymate.app`

### Xcode

1. Target > **Signing & Capabilities** > **+ Capability** > **Sign in with Apple** 추가

> 코드는 이미 `AuthRepositoryImpl.signInWithApple(idToken:nonce:)`에 구현되어 있음.
> `signInWithIdToken(provider: .apple)` 사용.

---

## 2. Kakao Sign In

카카오는 Supabase 기본 OIDC Provider가 아니므로 **Edge Function**으로 처리.

### Kakao Developer Console

1. [Kakao Developers](https://developers.kakao.com) > 애플리케이션 추가
2. **앱 키** > **REST API 키** 기록
3. **카카오 로그인** 활성화
4. **동의항목** > 닉네임, 이메일 필수 설정
5. **플랫폼** > iOS 추가 > **번들 ID**: `com.flymate.app`

### Supabase Edge Function 배포

```bash
# Supabase CLI 설치 (미설치 시)
brew install supabase/tap/supabase

# 프로젝트 연결
supabase login
supabase link --project-ref fvhrydkofctahxwyvsnp

# Edge Function 배포
supabase functions deploy kakao-sign-in
supabase functions deploy delete-account
```

### Supabase Dashboard - Edge Function 환경변수

**Settings** > **Edge Functions** 에서 시크릿 설정:

```bash
supabase secrets set KAKAO_REST_API_KEY=your-kakao-rest-api-key
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

> `SUPABASE_URL`과 `SUPABASE_ANON_KEY`는 Edge Function에서 자동으로 사용 가능.
> `SUPABASE_SERVICE_ROLE_KEY`는 Dashboard > Settings > API > service_role key에서 확인.

---

## 실행 순서 요약

1. `supabase_schema.sql` 실행 (테이블 + RLS)
2. `supabase_storage.sql` 실행 (버킷 + Storage RLS)
3. Apple Provider 설정 (Dashboard)
4. Kakao Developer 앱 생성
5. Edge Function 배포 (`kakao-sign-in`, `delete-account`)
6. Edge Function 시크릿 설정
