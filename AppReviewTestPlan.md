# 앱 심사 제출 전 검증 테스트 플랜

검증 방식: **자동** = 단위 테스트(TestStore), **수동** = 시뮬레이터/실기기 확인 필요.
핵심 영역(영상·댓글·대댓글)은 자동 + 수동 이중 검증.

## A. 영상 (핵심)

| ID | 테스트 케이스 | 방식 | 커버 |
|----|--------------|------|------|
| V-01 | 정확히 180초 영상은 업로드 허용 | 자동 | VideoUploadFeatureTests ✅ |
| V-02 | 180초 초과 영상 선택 시 `videoTooLong` 에러 표시, 제출 버튼 비활성 | 자동 | VideoUploadFeatureTests ✅ |
| V-03 | 초과 영상 → 정상 영상 재선택 시 에러 해제 | 자동 | VideoUploadFeatureTests ✅ |
| V-04 | 제목 없음/영상 미선택 시 `isValid == false` | 자동 | VideoUploadFeatureTests ✅ |
| V-05 | 업로드 진행률 표시 및 완료 후 피드 갱신 | 수동 | 시뮬레이터 |
| V-06 | 업로드 중 화면 이탈 시 Task 취소(고아 업로드 없음) | 수동 | 시뮬레이터 |
| V-07 | 영상 재생/일시정지/시크/음소거 | 수동 | 시뮬레이터 |
| V-08 | 피드 페이지네이션 (cursor 기반, 20개 단위) | 자동 | VideoFeedFeatureTests ✅ |
| V-09 | 영상 삭제 후 목록 반영 | 자동 | VideoDetailFeatureTests ✅ |
| V-10 | 네트워크 오류 시 에러 화면 + 재시도 동작 | 자동 | VideoFeedFeatureTests ✅ |

## B. 댓글(피드백) — 핵심

| ID | 테스트 케이스 | 방식 | 커버 |
|----|--------------|------|------|
| F-01 | 피드백 작성 성공 → 목록 반영, 입력 초기화 | 자동 | FeedbackWrite/CommentInputFeatureTests ✅ |
| F-02 | 작성 실패(서버 에러) → 에러 표시, 입력 내용 유지 | 자동 | CommentInputFeatureTests ✅ |
| F-03 | 빈 내용/공백만 입력 시 제출 불가 | 자동 | CommentInputFeatureTests ✅ |
| F-04 | 500자 초과 입력 시 잘림 | 자동 | CommentInputFeatureTests ✅ |
| F-05 | 타임스탬프가 재생 시점과 함께 저장됨 | 자동 | CommentInputFeatureTests ✅ |
| F-06 | 타임스탬프 탭 시 해당 시점으로 시크 | 수동 | 시뮬레이터 |
| F-07 | @멘션 자동완성 표시/선택/전체멘션 | 자동 | CommentInputFeatureTests ✅ |
| F-08 | 피드백 신고 플로우 (사유 선택 → 제출, 중복 신고 방지) | 자동 | ReportFeatureTests ✅ |
| F-09 | 받은/작성한 피드백 관리 탭 | 자동 | FeedbackManagementFeatureTests ✅ |
| F-10 | 이모지·장문·개행 포함 텍스트 정상 표시 | 수동 | 시뮬레이터 |

## C. 대댓글 — 핵심

| ID | 테스트 케이스 | 방식 | 커버 |
|----|--------------|------|------|
| C-01 | 답글 모드 진입 시 @작성자 자동 삽입, 해제 시 초기화 | 자동 | CommentInputFeatureTests ✅ |
| C-02 | 답글 제출 성공 → delegate 전달, 상태 초기화 | 자동 | CommentInputFeatureTests ✅ |
| C-03 | 답글 300자 초과 입력 시 잘림 | 자동 | CommentInputFeatureTests ✅ |
| C-04 | 댓글 목록 화면: 로딩 → 성공/실패 상태 전환 | 자동 | FeedbackCommentListFeatureTests ✅ (신규 작성) |
| C-05 | 댓글 목록에서 작성 성공 → 목록 맨 앞 삽입, 입력 초기화 | 자동 | FeedbackCommentListFeatureTests ✅ (신규 작성) |
| C-06 | 댓글 목록에서 작성 실패 → 에러 표시, 입력 내용 유지 | 자동 | FeedbackCommentListFeatureTests ✅ (신규 작성) |
| C-07 | 댓글 삭제 성공 → 목록에서 제거 | 자동 | FeedbackCommentListFeatureTests ✅ (신규 작성) |
| C-08 | 댓글 삭제 실패 → 에러 표시, 목록 유지(롤백 없음 확인) | 자동 | FeedbackCommentListFeatureTests ✅ (신규 작성) |
| C-09 | 댓글 300자 초과 입력 잘림 + 빈 입력 제출 불가 | 자동 | FeedbackCommentListFeatureTests ✅ (신규 작성) |
| C-10 | 댓글 화면 멘션 자동완성 | 자동 | FeedbackCommentListFeatureTests ✅ (신규 작성) |

## D. UGC 심사 요건 (App Store Guideline 1.2)

| ID | 요건 | 상태 |
|----|------|------|
| U-01 | 부적절 콘텐츠 신고 기능 | ✅ ReportFeature (피드백/유저/모집글/댓글 신고) |
| U-02 | 가해 사용자 차단 기능 | ✅ 구현 완료 (2026-08-11) — 피드백 시트/피드백 관리 메뉴에서 차단, 설정 > 차단한 사용자에서 해제. 서버 RLS로 차단 사용자 콘텐츠 숨김. 원격 DB에 `20260811000000_create_blocked_users.sql` 적용 필요 |
| U-03 | EULA/이용약관 동의 (무관용 정책 명시) | ✅ 구현 완료 (2026-08-12) — 로그인 후 최초 1회 커뮤니티 가이드라인 동의 화면(`TermsConsentFeature`). 무관용 정책·괴롭힘 금지·신고/차단·24시간 내 조치 명시 |
| U-04 | 부적절 콘텐츠 필터링 수단 | ❌ 미구현 (신고 후 운영자 조치로 갈음 가능하나 근거 필요) |
| U-05 | 개발자 연락 수단 | ✅ Settings 문의하기/버그 신고 메일 |
| U-06 | 영상·대댓글 자체 신고 수단 | ⚠️ `ReportTargetType`에 `video`/`feedbackComment` 케이스 없음. 단, 영상 피드백 시트에 사용자 신고/차단 메뉴 추가됨(2026-08-11)으로 주요 UGC 화면에서 신고 가능 |

## E. 계정 및 기타 심사 요건

| ID | 테스트 케이스 | 방식 | 커버 |
|----|--------------|------|------|
| E-01 | 회원 탈퇴 (계정 삭제) — 확인 알럿 → Apple 재인증 → 서버 삭제 | 자동 | SettingsFeatureTests ✅ |
| E-02 | Apple 로그인 / Kakao 로그인 (이메일 미동의 포함) | 자동 | LoginFeatureTests ✅ |
| E-03 | 구독/Paywall — 복원, 약관 링크 | 자동 | Subscription/PaywallFeatureTests ✅ |
| E-04 | 딥링크 진입 시 상태 처리 | 자동 | DeepLink 테스트 2종 ✅ |
| E-05 | 시연용 목데이터가 릴리즈 빌드에 포함 안 됨 (`#if DEBUG`) | 정적 검사 | ✅ 목 의존성/skipAuth는 `#if DEBUG` 가드, 릴리즈는 항상 live 의존성 등록 |

## 검증 결과 (2026-08-11)

- **자동 테스트: 200개 / 23개 스위트 전체 통과** (`xcodebuild test`, iPhone 17 Pro 시뮬레이터)
- 대댓글 목록 Feature 테스트 공백 발견 → `FeedbackCommentListFeatureTests.swift` 신규 작성 (9개 케이스, C-04~C-10)
- 잔여 항목: 수동 검증 5건 (V-05~07, F-06, F-10), UGC 요건 U-02/U-03/U-04/U-06

### 기타 발견 사항

- `Resources/MockThumbnails/` (2.8MB)가 `Project.swift`의 `Resources/**` glob으로 **릴리즈 번들에도 포함됨** — 목 전용이면 제외 권장
- `VideoPageView.isStaticMockVideo` (jpg/png URL이면 플레이어 대신 이미지 표시) 로직이 릴리즈 코드에 포함 — 실서비스 영상 URL은 항상 동영상이라 무해하지만 스크린샷용 코드임
