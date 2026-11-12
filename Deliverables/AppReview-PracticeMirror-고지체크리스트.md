# 미소 연습 거울 — 앱 심사 고지 체크리스트 (2026-09-06)

이번 심사 범위: 미소 연습 거울(ARKit), 미소 리포트·공유(QR), 앱 평가 요청, 1일 1미소 로컬 알림.

## 1. 완료된 고지 (제출 전 상태 확인용)

| 항목 | 내용 | 상태 |
|------|------|------|
| 카메라 권한 문구 | `NSCameraUsageDescription`: "미소 연습 거울에서 실시간 표정 측정을 위해 전면 카메라 접근 권한이 필요합니다." — 실제 용도와 일치 | ✅ 커밋됨 |
| 인앱 고지 | 거울 준비 화면에 상시 노출: "얼굴 데이터는 기기 안에서만 처리되며 저장·전송되지 않아요" | ✅ 커밋됨 |
| 개인정보처리방침 | privacy.html §2 "카메라 및 얼굴 데이터": ARKit 사용, 온디바이스 즉시 폐기, 목적 제한, 권한 철회 방법 + 통계 수치 기기 내 저장 문구 | ✅ 게시됨 (d625a8c, b633cde) |
| 알림 옵트인 | 1일 1미소 알림: 기본 OFF, 사용자가 직접 켜고 시간 선택, 설정에서 즉시 해제, 로컬 알림(서버 발송 없음) | ✅ 구현됨 |
| 평가 요청 | 커스텀 얼럿 없이 표준 `requestReview` API만 사용 (연 3회 상한 시스템 관리) | ✅ 구현됨 |

## 2. App Store Connect에서 할 일

### App Privacy (개인정보 라벨)
- **변경 불필요.** Apple 기준 "수집(collect)"은 기기 밖 전송을 의미 — 얼굴 데이터·미소 통계 모두 기기를 떠나지 않으므로 새 항목 추가 없음.
- 단, 기존 라벨(이메일·이름·사용자 콘텐츠·크래시 데이터 등)이 현 상태와 일치하는지 제출 전 한 번 훑기.

### 심사 노트 (App Review Information > Notes) — 붙여넣기용 초안

```
[New in this version: Smile Practice Mirror]

1. Camera / Face Data (Guideline 2.5.13, 5.1.1)
- The new "Smile Practice Mirror" uses the front camera with ARKit face
  tracking (ARFaceTrackingConfiguration) to display a real-time smile
  intensity gauge for video-interview practice.
- Face data (ARKit blendshape values) is processed on-device in real time
  and immediately discarded. No camera frames or face data are ever stored,
  recorded, or transmitted to our servers or any third party.
- Only derived, non-identifying statistics (e.g., smile ratio percentage)
  are stored locally on the device (UserDefaults) to personalize an
  optional local practice reminder. Nothing leaves the device.
- Face data is NOT used for authentication, advertising, or profiling.
- Our privacy policy discloses this:
  https://devk4nt.github.io/flymate-site/privacy.html (section 2)

2. How to test
- Study tab (first tab) → tap the round smile FAB at the bottom-right →
  grant camera permission → tap 시작 (Start) → smile at the camera →
  tap 종료 (Stop) after 10+ seconds to see the report.
- Requires a physical device with A12 or later (all iOS 17 devices).

3. Notifications
- "1일 1미소" daily practice reminder is a LOCAL notification, opt-in only
  (off by default), user-chosen time, cancellable anytime in Settings.
  No remote/marketing push is involved.

4. Rating prompt
- We use the standard SKStoreReviewController / requestReview API only,
  triggered after repeated successful practice sessions. No custom rating
  dialogs.
```

## 3. 법적 검토 요약 (한국법 기준)

| 이슈 | 판단 | 근거/조치 |
|------|------|-----------|
| 얼굴 데이터 = 생체인식정보? | **해당 없음에 가까움** — 개인 식별 목적이 아닌 표정 수치(비식별 파생값)이고 저장·전송하지 않음. 그래도 처리방침에 명시 완료 | privacy.html §2 |
| 미소 통계 기기 저장 | 기기 한정 저장·미전송 명시 | privacy.html §2 추가 문구 |
| 1일 1미소 알림 = 광고성 정보? | **아님** — 이용자가 직접 설정한 서비스 리마인더(알람 성격), 옵트인·시간 자율 선택·즉시 해제 가능. 야간 발송 제한 규정은 이용자가 시간을 직접 고르므로 비적용 | 정보통신망법 §50 취지 |
| 공유 카드 | 수치·그래프만 포함(얼굴 이미지 없음), 사용자가 직접 내보내는 구조 | 방침 충돌 없음 |

## 4. 제출 전 마지막 확인

- [ ] 심사 빌드는 **release-upload.yml 워크플로**로 (로컬 베타 macOS 빌드 = Invalid Binary)
- [ ] privacy.html 반영 확인 (GitHub Pages, 시크릿 창에서 §2 표시 확인)
- [ ] What's New(버전 노트)에 카메라 기능 언급: "전면 카메라로 미소를 실시간 측정하는 연습 거울 추가 (얼굴 데이터는 기기에서만 처리)"
- [ ] 스크린샷에 실제 인물 사진 쓸 경우 초상권 동의 (셀프 촬영이면 무관)
