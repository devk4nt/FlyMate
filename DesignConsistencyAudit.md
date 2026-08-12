# FlyMate 앱 심사 전 디자인 일관성 감사

- 감사일: 2026-08-11
- 대상: `Packages/Presentation/Sources/Presentation`의 SwiftUI 구현 52개 파일, 디자인 토큰/공통 컴포넌트, 최신 iPhone 제출 이미지 7장과 iPad 제출 이미지 1장
- 기준: 프로젝트의 `FMColors`, `FMTypography`, `FMSpacing`, `FMSizing`, 공통 컴포넌트 및 iOS Dynamic Type/Reduce Motion/최소 터치 영역 원칙
- 범위 밖: 비즈니스 로직, 서버 정책, 결제/UGC 심사 요건(별도 `AppReviewTestPlan.md` 참조)

## 결론

현재 화면은 밝은 하늘색 브랜드 톤, 8pt 기반 간격, 20pt 카드 radius를 중심으로 전반적인 인상은 통일되어 있다. 최초 감사에서 확인한 아래 P1 항목은 2026-08-11 개선 및 회귀 검증을 완료했다.

1. 브랜드 그라디언트 위 흰색 텍스트 대비가 부족하다.
2. 타이포그래피 토큰 대부분이 Dynamic Type을 지원하지 않는다.
3. 전역 토스트가 현재 호출 방식에서는 표시되지 않는다.
4. 알림 버튼의 터치 영역이 32×32pt이다.
5. 가로 영상 상세의 과도한 레터박스가 정보 계층을 분리한다.
6. 모집 마감 카드의 전체 opacity가 콘텐츠 대비를 낮춘다.

## P1 개선 적용 결과

| 항목 | 상태 | 적용 내용 |
|---|---|---|
| DS-001 브랜드 대비 | 완료 | `brandGradient`를 #306DA6 → #051766 계열로 강화하고 `onBrand` 전경 토큰을 적용했다. 가장 밝은 지점 기준 흰색 대비는 약 5.43:1이다. |
| DS-002 Dynamic Type | 완료 | `FMTypography`의 고정 크기 13개를 semantic text style로 전환하고, UIKit 멘션 입력기는 `UIFontMetrics`와 브랜드 색상 asset을 사용한다. 접근성 크기에서 스터디 hero 지표·버튼은 1열로 전환한다. |
| DS-003 전역 토스트 | 완료 | `FMToast`를 presentation 상태에 의해 즉시 보이는 순수 View로 단순화하고 자체 취소 가능한 auto-dismiss task와 Reduce Motion 대응을 적용했다. |
| DS-004 알림 터치 영역 | 완료 | 심볼 크기는 유지하고 버튼의 외부 frame/content shape를 44×44pt로 확대했다. |
| DS-005 영상 레터박스 | 완료 | 원본 비율은 유지하면서 썸네일 기반 blur/fill backdrop을 추가하고 실제 AVPlayer의 letterbox 영역을 투명 처리했다. |
| DS-006 마감 카드 대비 | 완료 | 카드 전체 opacity를 제거하고 비활성 배경·테두리만 semantic color로 구분했다. |

## 디자인 시스템 8단계 정리 결과 (2026-08-12)

버튼 색상 체계 정리 이후, 잔여 디자인 항목을 우선순위 순서대로 개선했다.

| 순서 | 영역 | 상태 | 적용 내용 |
|---:|---|---|---|
| 1 | 카드 | 완료 | `FMCard`에 `standard`, `feed`, `hero` 역할을 추가하고 스터디·모집·피드백 카드와 compact empty card를 공통화했다. production 사용은 1곳에서 6곳으로 늘었다. |
| 2 | Radius·그림자 | 완료 | `hero`, `artwork`, `appIcon` radius와 `card`, `hero`, `section`, `floating`, `avatar` shadow token을 추가했다. 기존 28/36/38pt 직접 radius는 화면 코드에서 제거했다. |
| 3 | Semantic color | 완료 | launch/media 전용 semantic token을 추가하고 화면의 primitive palette 직접 참조를 제거했다. 읽지 않은 알림 포인트는 Coral `highlight`로 통일했다. |
| 4 | 입력·선택 컨트롤 | 완료 | `FMTextField`에 48pt 최소 높이, focus/error border를 적용하고 `fmInputSurface`로 TextEditor·상세 입력 surface를 통합했다. Picker/DatePicker tint도 action color에 맞췄다. |
| 5 | 내비게이션·모달 | 완료 | 전역 tab/navigation action tint를 adaptive `actionForeground`로 통일하고 프로필 편집 Sheet의 변경 중 dismiss를 방지했다. 편집 화면은 `취소`, 읽기/관리 화면은 `닫기` 명칭을 유지했다. |
| 6 | 타이포그래피 | 완료 | `eyebrow`, `cardTitle`, `metric`, `badgeStrong` semantic typography를 추가하고 주요 피드·카드의 직접 시스템 font 사용을 토큰으로 이동했다. |
| 7 | 상태 화면 | 완료 | `FMEmptyState`에 compact layout을 추가하고 빈 카드와 오류 아이콘의 크기·surface·색상 계층을 통일했다. |
| 8 | 접근성·반응형 | 완료 | 주요 피드는 regular width 760pt, 입력/상세 화면은 640pt로 최대 폭을 제한했다. 복사·스크롤·피드백 강조 애니메이션에 Reduce Motion 대응을 추가했다. |

- 정적 검사: `git diff --check` 통과, 화면의 primitive palette 직접 사용 0건, 28/36/38pt 직접 radius 0건.
- iPhone 17 Pro / iOS 26.3.1 전체 테스트: **212개 통과, 실패 0, skip 0**.

## Air Blue + Coral 컬러 조정 (2026-08-12)

`Sky Lilac` 시안을 검토한 뒤 앱의 기존 항공 이미지를 더 잘 전달하는 Air Blue 컬러톤으로 롤백했다. 알림과 소량의 강조 포인트에는 Coral Pink를 유지했다.

| 역할 | Light | Dark | 적용 범위 |
|---|---|---|---|
| Primary / Accent | `#4AA9D8` | `#8DD7EE` | 선택 탭, 링크, 아이콘, 입력 커서 |
| Action Fill | `#306DA6` | 동일 | primary button, 전송, 승인 |
| Brand Gradient | `#306DA6 → #051766` | 동일 | hero, 프로필 카드, 브랜드 artwork |
| Secondary | `#8DD7EE` | `#4AA9D8` | 장식, 부드러운 강조 면 |
| Feature Gradient | `#306DA6 → #051766` | 동일 | 업로드·온보딩 강조 면 |
| Highlight | `#FF7F9F` | `#FF9BB5` | 알림 배지와 소량의 포인트 |
| Canvas | `#F2FAFF` | `#0D121A` | 주요 화면 배경 |

- 흰색 대비: brand/feature gradient `5.44:1 → 15.90:1`.
- 선택 배지와 필터는 흰색 대비가 확보된 `accentFill(#306DA6)`을 사용한다.
- 알림 카운트 배지와 알림 목록 아이콘은 `highlight`/`attentionFill` Coral Pink를 사용한다.
- Tuist 재생성 및 iPhone 17 Pro / iOS 26.3.1 전체 테스트: **212개 통과, 실패 0, skip 0**.

## 우선순위별 발견 항목

### P1 — 제출 전 수정/확인 권장

#### DS-001. 밝은 브랜드 그라디언트의 텍스트 대비 부족 — 개선 완료

- 근거
  - `FMColors.brandGradient`는 `airBlue`(#4AA9D8)에서 밝은 `secondary`(#8DD7EE)로 이어진다.
  - 흰색과의 계산 대비는 각각 약 **2.64:1**, **1.60:1**이다. 일반 텍스트 권장값 4.5:1에 못 미친다.
  - `FMButton` primary가 이 그라디언트 위에 항상 흰색 라벨을 사용한다.
  - 제출 이미지의 스터디/모집 hero에서 흰색 제목·설명이 실제로 흐리게 보인다.
- 위치
  - `DesignSystem/Tokens/FMColors.swift:14-15, 80-85`
  - `DesignSystem/Components/FMButton.swift:52-58, 91-94`
  - `Features/Study/StudyList/StudyListView.swift:106-169`
  - `Features/Recruit/RecruitListView.swift:117-169`
- 권장
  - hero/primary button 전용으로 더 어두운 그라디언트 토큰을 만들거나, 현재 그라디언트에는 `koreanAirDarkBlue` 계열 전경색을 사용한다.
  - `onBrandPrimary`, `onBrandMuted`, `brandSurfaceStrong` 같은 semantic token을 추가하고 대비 테스트를 자동화한다.

#### DS-002. 타이포그래피 토큰이 Dynamic Type을 우회 — 개선 완료

- 근거
  - `FMTypography` 15개 스타일 중 13개가 `.system(size:)` 고정 pt이며 semantic text style은 2개뿐이다.
  - 화면에서 토큰 밖 고정 `.font(.system(size:))` 사용이 29곳, `UIFont.systemFont(ofSize:)` 사용이 5곳이다.
  - 토큰 밖 semantic `.headline`, `.subheadline`, `.caption` 직접 사용도 52곳이라 같은 의미의 텍스트가 토큰/시스템 스타일로 혼재한다.
  - `@ScaledMetric` 또는 `.dynamicTypeSize` 기반 레이아웃 대응이 없다.
- 위치
  - `DesignSystem/Tokens/FMTypography.swift:12-68`
  - `DesignSystem/Components/FMMentionTextEditor.swift:18-28, 69-79, 100-115`
  - 예: `Features/Auth/LoginView.swift:37, 46`, `Features/Subscription/SubscriptionView.swift:43, 62`, `Features/Settings/SettingsView.swift:213`
- 영향
  - 접근성 글자 크기에서 본문이 확대되지 않거나, SwiftUI 텍스트와 UIKit 멘션 입력기의 크기가 서로 달라질 수 있다.
- 권장
  - `.system(.body)`, `.system(.headline)` 등 semantic style로 매핑하고 weight/design만 토큰에서 지정한다.
  - 고유 브랜드 크기가 꼭 필요하면 `Font.system(size:..., relativeTo:)`와 `UIFontMetrics`를 사용한다.
  - 접근성 크기 AX1~AX5에서 온보딩, 카드, 입력창, 하단 탭을 캡처 테스트한다.

#### DS-003. 전역 토스트가 렌더링되지 않는 호출 경로 — 개선 완료

- 근거
  - `FMToast`의 `isVisible` 기본값은 `false`이며 `.show()`가 호출되어야 `true`가 된다.
  - `FMToastModifier`와 Preview는 `.show()`를 사용하지만 `AppView`는 `FMToast(...)`만 직접 생성한다.
- 위치
  - `App/AppView.swift:62-74`
  - `DesignSystem/Components/FMToast.swift:45-85, 113-121`
- 영향
  - 성공/오류/안내 피드백이 사용자에게 보이지 않아 저장·실패 상태가 무반응처럼 느껴진다.
- 권장
  - `AppView`에서 공통 `fmToast` modifier를 사용하거나, `FMToast` 자체를 presentation 상태에 의해 바로 보이는 순수 View로 단순화한다.
  - 표시, 3초 후 해제, Reduce Motion 동작을 UI 또는 View 단위 테스트로 추가한다.

#### DS-004. 알림 버튼 최소 터치 영역 미달 — 개선 완료

- 근거
  - `FMNotificationBell`의 실제 label과 content shape가 모두 32×32pt이다.
- 위치
  - `DesignSystem/Components/FMNotificationBell.swift:13-27`
- 영향
  - 권장 최소 44×44pt보다 작아 상단 내비게이션에서 누르기 어렵다.
- 권장
  - 심볼은 19pt로 유지하되 외부 frame/content shape를 최소 44×44pt로 확대한다.

#### DS-005. 가로 영상에서 과도한 레터박스와 정보 계층 분리 — 개선 완료

- 근거
  - 정적 심사용 영상 경로가 `.aspectRatio(contentMode: .fit)`로 전체 화면에 배치된다.
  - 제출 이미지 `03-video-detail.jpg`에서 영상보다 검은 빈 영역이 훨씬 크고, 영상과 하단 메타정보가 멀리 분리된다.
  - 반면 `07-timestamp-feedback.jpg`는 세로로 꽉 찬 구성이어서 같은 영상 상세 플로우 안에서도 밀도가 크게 다르다.
- 위치
  - `Features/Video/VideoDetail/VideoPageView.swift:67-92`
  - `Features/Video/VideoDetail/VideoPageView.swift:96-138`
- 권장
  - 가로 영상은 영상 영역의 최대 높이/세로 위치를 명시하고 하단 정보 영역을 인접 배치하거나, 배경 blur/fill을 추가한다.
  - 16:9, 9:16, 1:1 세 비율을 실제 플레이어와 정적 심사 데이터 모두에서 비교한다.

#### DS-006. 모집 마감 카드가 전체 opacity로 저대비 처리됨 — 개선 완료

- 근거
  - 모집 마감 시 카드 전체에 `.opacity(0.65)`가 적용되어 제목·날짜·메타정보까지 함께 흐려진다.
  - 제출 이미지 `06-recruitment.jpg`의 두 번째 카드에서 정보 판독성이 현저히 낮다.
- 위치
  - `Features/Recruit/RecruitListView.swift:300-355`
- 권장
  - 카드 전체 opacity는 제거하고 상태 배지/배경색만 비활성 semantic token으로 바꾼다. 본문 텍스트는 최소 `secondaryLabel` 대비를 유지한다.

### P2 — 디자인 시스템 정리 권장

#### DS-007. radius 토큰 밖 값이 반복됨

- 정적 결과: 토큰 밖 radius 사용 9곳.
- 반복값
  - 28pt: 로그인 아이콘 및 스터디/모집 hero 5곳
  - 36pt: 온보딩 artwork 2곳
  - 38pt: splash 아이콘 1곳
  - 22pt: skeleton avatar 1곳(원형의 절반값이라 예외 허용 가능)
- 위치
  - `App/SplashView.swift:35`
  - `Features/Auth/LoginView.swift:33`
  - `Features/Onboarding/OnboardingView.swift:214-217`
  - `Features/Study/StudyList/StudyListView.swift:137, 151`
  - `Features/Recruit/RecruitListView.swift:153, 167`
- 권장
  - 28pt는 `CornerRadius.hero`, 36/38pt는 artwork/appIcon 전용 sizing token으로 명명한다.
  - 단순히 `xl = 20`을 임의 확장하기보다 컴포넌트 역할이 드러나는 semantic 이름을 사용한다.

#### DS-008. 그림자 시스템이 사실상 적용되지 않음

- 정적 결과
  - feature/app 영역의 shadow 34곳이 화면별 값이다.
  - 전체 shadow 호출 중 38곳이 `FMShadow.cardRadius`를 사용하지 않는다.
  - `FMShadow`는 카드 한 종류만 표현하여 hero, floating control, overlay, video control을 수용하지 못한다.
- 예시
  - hero: radius 22 / y 12
  - 카드: radius 14 / y 7, radius 12 / y 6
  - floating action: radius 7 / y 4
- 권장
  - `FMShadow.card`, `hero`, `floating`, `overlayOnMedia`처럼 역할별 modifier/token으로 통합한다.

#### DS-009. 공통 `FMCard`와 실제 카드 스타일이 분리됨

- 정적 결과
  - production에서 `FMCard` 사용은 1곳뿐이며, 화면별 custom shadow는 34곳이다.
  - 같은 카드 계층인데 배경/테두리/그림자/radius 조합이 화면마다 별도로 구현된다.
- 위치
  - `DesignSystem/Components/FMCard.swift`
  - `Features/Study/StudyList/StudyListView.swift:292-350`
  - `Features/Recruit/RecruitListView.swift:300-355`
  - `Features/Feedback/FeedbackList/FeedbackListView.swift:244-262`
- 권장
  - `FMCard`에 `standard`, `feed`, `hero` 정도의 제한된 variant를 추가하고 화면 구현을 이동한다.

#### DS-010. 브랜드 색상 사용 역할이 혼재

- 정적 결과
  - 화면/컴포넌트에서 `FMColors.airBlue` 직접 사용 39회, `primary` 51회, `accent` 27회.
  - 주석상 interaction color는 `accent`지만 실제 선택/버튼/테두리에 세 이름이 혼재한다.
  - `airBlue`는 고정 색이고 `primary`는 다크모드 asset이라 appearance에 따라 동작도 다르다.
- 영향
  - 같은 파란색처럼 보이지만 다크모드에서 화면별로 밝기/대비가 달라진다.
- 권장
  - primitive palette(`airBlue`)는 token 파일 내부에서만 사용하고, 화면에서는 `accent`, `brandInk`, `border`, `surface` 같은 semantic color만 허용한다.

#### DS-011. Reduce Motion 처리가 일부 애니메이션에만 적용됨

- 정적 결과
  - 애니메이션 호출 11곳 중 Reduce Motion 환경을 읽는 파일은 4개다.
  - 토스트, 가입코드 복사 피드백, 모집 상세 전환, 피드백 highlight 애니메이션은 별도 대응이 없다.
- 위치
  - `DesignSystem/Components/FMToast.swift:71-82`
  - `Features/Study/StudyDetail/StudyDetailView.swift:463`
  - `Features/Recruit/RecruitDetail/RecruitDetailView.swift:46`
  - `Features/Video/VideoDetail/VideoFeedbackSheet.swift:307`
- 권장
  - 공통 motion token 또는 `fmAnimation` helper로 duration/비활성 정책을 통일한다.

#### DS-012. iPad에서 정보 밀도와 여백이 최적화되지 않음

- 근거
  - 최신 iPad 13-inch 제출 이미지에서 hero와 카드가 화면 전체 너비를 차지하지만 콘텐츠는 상단 절반에 몰려 있고 하단은 크게 비어 있다.
  - iPad가 정식 destination에 포함되어 있어 심사 화면에서도 노출될 수 있다.
- 권장
  - regular width에서 최대 콘텐츠 폭을 제한하고 2열 카드 또는 보조 패널을 검토한다.
  - portrait/landscape, Split View 1/2 및 1/3 폭을 별도 확인한다.

### P3 — 낮은 위험/정리 항목

#### DS-013. 간격 토큰은 대체로 준수하지만 보정값이 산재

- 양호: 주요 stack과 padding은 대부분 `FMSpacing`을 사용한다.
- 예외: 13, 14, 10, 1pt padding과 `FMSpacing.sm + 1`, `FMSpacing.xxs + 2` 같은 보정값이 있다.
- 권장: 픽셀 정렬용 1pt는 허용 사유를 주석으로 남기고, 반복되는 14pt는 token 또는 control vertical inset으로 정의한다.

## 양호한 부분

- `FMColors`의 system background/label 계열은 라이트·다크모드에 맞춰 adaptive하게 정의되어 있다.
- 색상 asset의 `Primary`, `Secondary`, 앱 `AccentColor`에는 dark appearance가 모두 포함되어 있다.
- `FMSpacing`은 2/4/8/12/16/20/24/32/40의 일관된 scale을 사용한다.
- `FMButton`은 높이 52pt로 충분한 터치 영역과 일관된 loading/disabled 상태를 제공한다.
- onboarding, splash, shimmer는 Reduce Motion을 명시적으로 고려한다.
- 다수의 핵심 컨트롤에 접근성 label/hint/identifier가 이미 적용되어 있다.
- 최신 iPhone 제출 화면들의 카드 radius, 화면 좌우 여백, 하단 탭 구조는 대체로 일관적이다.

## 시트 디자인 통일 적용 (2026-08-12)

`StudyCreateView`를 시트의 기준 화면으로 정하고 다음 규칙을 공통화했다.

- 배경: 모든 앱 시트에 `FMColors.canvas`와 동일한 presentation background 적용
- 상호작용 색상: sheet 내부 navigation/control tint를 `FMColors.actionForeground`로 통일
- 콘텐츠: 입력·선택 영역은 `FMCard`의 standard radius, border, shadow 사용
- 주요 동작: 화면 하단 `safeAreaInset` + 좌우 `md`/상단 `sm`/하단 `xs` + ultra-thin material 사용
- 내비게이션: inline title과 cancellation action을 유지하고, 본문에 중복 CTA를 두지 않음

적용 범위:

- 생성·입력: 스터디 만들기, 스터디 참여, 모집 글 생성/수정, 모집 재개, 공지 편집, 신고, 버그 신고, 프로필 수정
- 조회·관리: 알림, 스터디 관리, 차단 사용자, 멤버 활동 현황, 구독 관리, paywall
- 피드백: 영상 피드백, 피드백 댓글
- 시스템 소유 화면인 사진 선택기와 메일 작성기는 iOS 기본 시각 언어를 유지

구조 차이가 컸던 `JoinStudyView`, `ReportView`, 모집 재개 시트는 `설명 헤더 → 카드형 콘텐츠 → 고정 하단 CTA` 구조로 재구성했다.

## 버튼·시트 외 디자인 통일 적용 (2026-08-12)

사용자가 빈 계정과 일반 탐색 과정에서 자주 접하는 화면부터 다음 순서로 개선했다.

1. 상태 화면
   - 피드백 목록, 피드백 대기열, 스터디 관리의 별도 빈 화면을 `FMEmptyState`로 통합
   - `fullScreen`, `compact`, `card` layout과 의미 색상 tint를 지원
   - 참여 요청의 초기 중앙 spinner를 list skeleton으로 변경
2. 카드 표면
   - 스터디 생성, 모집 글 생성, 영상 업로드 form card를 `FMCard.standard`로 통합
   - 피드백 헤더와 프로필 정보 영역을 공통 card variant로 이동
3. 타이포그래피·색상
   - 설정 및 관리 화면의 직접 system text style을 `FMTypography` 역할로 이동
   - `iconAccent`, `selection`, `badgeForeground`, `decorativeBrand` semantic color 추가
4. 입력·아이콘
   - 댓글 composer를 `fmComposerSurface`로 통합해 background, radius, border, focus 표현 일치
   - `FMSizing.IconContainer`의 `sm/md/lg/hero` 규격 추가
5. 반응형·내비게이션
   - 설정, 피드백 관리, 스터디 상세, 참여 요청·멤버 관리에 최대 콘텐츠 폭 적용
   - 스터디 상세 navigation title을 inline으로 통일
6. 모션·그림자·간격
   - 영상 피드백 자동 스크롤에 Reduce Motion 적용
   - 헤더/hero 그림자를 `FMShadow` 역할 토큰으로 이동
   - 13/14pt placeholder 보정값을 spacing token으로 정리

정적 지표 변화:

| 항목 | 적용 전 | 적용 후 |
|---|---:|---:|
| `FMCard` feature 사용 | 12 | 18 |
| 직접 구현 rounded surface | 59 | 47 |
| 직접 semantic/system font 지정 | 69 | 45 |
| feature shadow 호출 | 29 | 25 |
| `FMSizing.ContentWidth` 적용 | 6 | 11 |

미디어 overlay, 앱 hero artwork, 시스템 목록처럼 역할상 별도 표현이 필요한 화면은 공통 카드로 강제하지 않았다.

## 수행한 검증

### 정적 검사

| 항목 | 결과 |
|---|---:|
| SwiftUI 구현 파일 | 52 |
| 화면/Sheet/Bar 파일 | 37 |
| 고정 SwiftUI 폰트(토큰 밖) | 29 |
| 고정 UIKit 폰트 호출 | 5 |
| `FMTypography` 고정 크기 token | 0/15 |
| 토큰 밖 radius | 9 |
| `FMShadow.cardRadius` 미사용 shadow | 38 |
| `FMColors.airBlue` 화면 직접 사용 | 39 |
| animation 호출 | 11 |
| Reduce Motion reader | 4 |

### 시각 검사

확인 이미지:

- iPhone 6.9-inch: study home, video feed, video detail, feedback management, study detail, recruitment, timestamp feedback
- iPad 13-inch: study home

주요 결과:

- 카드와 하단 탭의 기본 언어는 일관적이다.
- hero의 흰색 텍스트 대비, 마감 카드의 전체 흐림, 가로 영상 레터박스, iPad 빈 공간은 수정 후보로 확인됐다.

### 빌드/테스트

- `FlyMate.xcodeproj` 단독 빌드: 실패. Tuist 외부 모듈(`ComposableArchitecture`, `KakaoSDK*`, `Kingfisher`, `Supabase`)을 project 단독으로 resolve하지 못함. 소스 오류와 구분 필요.
- `FlyMate.xcworkspace` Debug Simulator 빌드: **성공**.
- 테스트 최초 실행: 실행 중 새로 추가된 `BlockedUser`/`BlockedUserDTO`가 기존 생성 프로젝트에 포함되지 않아 컴파일 중단.
- `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer tuist generate --no-open`으로 프로젝트 재생성: **성공**.
- P1 개선 후 전체 unit test 재실행: **209개 통과, 실패 0, skip 0** (iPhone 17 Pro, iOS 26.3.1 Simulator).
- 일반 글자 크기 및 `accessibility-extra-large`에서 앱을 직접 실행해 스터디 홈을 캡처 확인했다. 접근성 크기에서 발견한 hero 2열 줄바꿈은 1열 전환으로 보완 후 재확인했다.
- Xcode beta 27의 generic simulator 빌드는 외부 `xctest-dynamic-overlay`의 `_fail` 심볼 호환 오류로 중단됐으나, iOS 26.3.1 지정 시뮬레이터의 앱 빌드 및 전체 테스트는 성공했다.
- 잔여 빌드 경고: Supabase/TCA deprecated API와 `VideoPlayerView`/`ProfileEditView`의 Swift 6 actor-isolation 경고. 현재 빌드·테스트를 막지는 않지만 정식 Swift 6 오류 모드 전환 전에 정리 권장.
- 시트 통일 적용 후 전체 unit test 재실행: **212개 통과, 실패 0, skip 0** (iPhone 17 Pro, iOS 26.3.1 Simulator).
- 버튼·시트 외 통일 및 한국어 날짜 포맷 테스트 추가 후 전체 unit test 재실행: **213개 통과, 실패 0, skip 0** (iPhone 17 Pro, iOS 26.3.1 Simulator).

## 수정 권장 순서

1. DS-001~006 P1 개선 완료
2. DS-007~010 token/component 정리
3. DS-011~012 접근성 모션 및 iPad 레이아웃 회귀 테스트

## 최종 상태

- 디자인 정적 감사 및 P1 개선: **완료**
- 제출 이미지 시각 감사: **완료**
- 빌드: **성공** (`FlyMate.xcworkspace`, Debug, iOS Simulator)
- 단위 테스트: **213/213 통과**
