# Phase 0: docs

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다.

```bash
git status --porcelain -- docs/ Mofit/ MofitTests/ project.yml README.md tasks/7-camera-permission-recovery/
```

출력되는 파일이 있으면 working tree 가 더럽다. 진행하지 말고 `tasks/7-camera-permission-recovery/index.json` 의 phase 0 status 를 `"error"` 로 변경, `error_message` 에 `dirty working tree before phase 0` 로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/prd.md` — 가치제안 (이번 task 는 §5 "리스크 · 한계" 의 11번 "카메라 권한 거부 유저 동선" 을 해소)
- `docs/spec.md` — §1 탭/화면 구성, §2 핵심 상태머신(특히 §2.4 카메라 파이프라인, §2.5 진단 힌트, §2.6 autosave), §5 네트워킹 분기 테이블
- `docs/adr.md` — **ADR-017** (스쿼트 전용 포지셔닝 — 이번 ADR-019 본문은 이 범위와 일치해야 한다), ADR-018(진단 힌트), ADR-009(autosave delta). ADR-001(Apple Vision) ~ ADR-018 까지 번호 연속성 확인 — ADR-019 가 다음 번호.
- `docs/code-architecture.md` — `Camera/CameraManager.swift`, `Views/Tracking/TrackingView.swift`, `Views/Home/HomeView.swift` 배치. 이번 task 는 `Views/Tracking/` 하위에 `CameraPermissionResolver.swift` 1 파일 추가 예정(phase 1). `Camera/` 디렉토리에는 파일 추가 없음.
- `docs/testing.md` — "XCTest 타겟" 섹션(iter 7 신설). 이번 phase 에서 **현재 대상 불릿에 `CameraPermissionResolver` 한 줄 추가**. 추가 섹션 신설 금지.
- `docs/user-intervention.md` — **이번 task 는 user-intervention 항목을 추가하지 않는다** (iter 8 CTO 조건 5: "실기기 QA 필수화 금지"). 기존 §트래킹 진단 힌트 / §트래킹 autosave 항목 불변.
- `iterations/8-20260424_234219/requirement.md` — iteration 원문. §구현 스케치 1~5, §CTO 승인 조건부 조건 1~5 가 이번 task 설계의 원전.

그리고 이전 task 전례(Phase 0 docs 업데이트 스타일 참고용):

- `tasks/6-coaching-generator/phase0.md` — 가장 최근 task 의 Phase 0. docs delta 작성 톤/형식 참조.
- `tasks/6-coaching-generator/docs-diff.md` — Phase 0 완료 후 runner 가 자동 생성한 diff.
- `tasks/4-diagnostic-hint/phase0.md` — ADR 신설(ADR-018) 패턴 참조용. 이번 ADR-019 신설도 유사 구조.

이 Phase 는 **코드 변경 없음**. `docs/` 3개 파일(adr.md, spec.md, testing.md)만 수정한다. `Mofit/` · `project.yml` · `README.md` · `server/` · `MofitTests/` · `docs/user-intervention.md` · `docs/data-schema.md` · `docs/prd.md` · `docs/flow.md` · `docs/mission.md` · `docs/code-architecture.md` 는 터치 금지.

## 작업 내용

### 대상 파일 (정확히 3개)

1. `docs/adr.md` — **ADR-019 신설** (ADR-018 뒤에 신규 섹션 1개 추가).
2. `docs/spec.md` — §2 상태머신 섹션에 **§2.8 카메라 권한 분기** 신규 서브섹션 추가.
3. `docs/testing.md` — "XCTest 타겟" 섹션 내 "현재 유일 대상" → "현재 대상" 표현 변경 + `CameraPermissionResolver` 불릿 1줄 추가.

### 목적

iter 8 persona(`home-workout-newbie-20s`, `risk_preference: conservative`, `trust_with_salesman: 40`, `personality_notes: "3일 써보고 아니면 삭제"`) 가 "설치 → 카메라 권한 거부 → 빈 검은 화면 → 회복 경로 없음 → 삭제" 경로로 이탈하는 구조적 공백을 제거한다. pain 의 본질은 `reject_triggers` "'카메라 권한 없으면 아무것도 못함' 으로 시작" 과 현 `CameraManager.swift` 의 권한 요청 코드 전무 상태가 1:1 로 매칭. 해결책은 **권한 상태별 3분기 뷰 + 설정 딥링크 + 홈 화면 배지(denied/restricted 만)**. 이번 Phase 0 는 이 결정을 문서에 박는다.

### 구체 지시

#### 1) `docs/adr.md` — ADR-019 신설

**삽입 위치**: `### ADR-018: 트래킹 미검출 진단 힌트 (2종 고정)` 블록의 끝(마지막 문장 "`조도 케이스 실기기 생략 가능.`" 뒤) 다음 빈 줄 후. 파일 말미가 ADR-018 섹션으로 끝나는지 확인하고, 그 뒤에 빈 줄 1개 후 아래 블록 통째로 append.

```markdown
### ADR-019: 카메라 권한 거부 복구 플로우 (설정 딥링크 + 상태별 폴백 UI)
**결정**: `TrackingView` 진입 시 `AVCaptureDevice.authorizationStatus(for: .video)` 를 3분기한다. `.notDetermined` → `AVCaptureDevice.requestAccess(for: .video)` 인라인 요청 + completion 에서 상태 재계산 + `.active` scenePhase 전이 시 재조회. `.denied` / `.restricted` → 풀스크린 폴백 카드 (타이틀 "카메라 권한이 필요해요" + 프라이버시 서브카피 + Primary "설정에서 권한 켜기" → `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)` + Secondary "홈으로 돌아가기" → dismiss). `.authorized` → 기존 트래킹 뷰. `HomeView` "스쿼트 시작" 버튼 아래에 `.denied` / `.restricted` **에 한해** "카메라 권한 필요" 작은 배지 노출(CTO 조건 2 — `.notDetermined` 에서 배지 금지, reject_trigger "'카메라 권한 없으면 아무것도 못함' 으로 시작" 재트리거 방지). 권한 상태 → 분기 enum 매핑은 Foundation-only pure struct `CameraPermissionResolver.decide(status:)` 로 추출해 `MofitTests/CameraPermissionResolverTests.swift` 에서 4 케이스(authorized/denied/restricted/notDetermined) assert (iter 7 선례와 동일 패턴).
**이유**: iter 8 설득력 시뮬(run_id: `home-workout-newbie-20s_20260424_234401`, keyman `decision: drop`, `confidence: 55`) 에서 `risk_preference: conservative` + `personality_notes: "3일 써보고 아니면 삭제"` 페르소나가 설치 직후 카메라 권한 거부 시점에 회복 경로 없이 즉시 이탈하는 경로가 최종 판정 실패의 독립 사유. 현 `CameraManager.swift` 는 `AVCaptureDevice.default(..., position: .front)` 직접 호출 전에 `AVCaptureDevice.authorizationStatus` / `requestAccess` 체크가 전무해, `.denied` 상태 유저는 빈 검은 preview + 무의미한 stopButton 만 본 채로 고립. TestFlight/앱스토어 출시 전 시점에 복구 플로우를 넣어야 초기 별점·리뷰 피해를 차단.
**범위**: `TrackingView` 진입 플로우 한정. ADR-017 스쿼트 전용 스코프와 일치. 본문에서 "스쿼트 이외 확장 시 이 뷰를 재활용한다" 식 일반화 금지(CTO 조건 1) — "카메라 권한을 요구하는 모든 진입점에 동일 폴백" 수준으로만 서술. 파일 변경 매트릭스: (a) `Mofit/Views/Tracking/TrackingView.swift` 최상단 3분기 + 기존 tracking body 를 `.ready` 브랜치에 한정 + `viewModel.startSession` 호출을 `.ready` 가드 안으로 이동, (b) `Mofit/Views/Home/HomeView.swift` "스쿼트 시작" 버튼 아래 배지 1개 + `@State var cameraStatus` + `.onAppear` + `.onChange(of: scenePhase)` 재조회, (c) `Mofit/Views/Tracking/CameraPermissionResolver.swift`(신규) pure struct + `CameraPermissionDecision` enum(3 case) + `@unknown default` fail-closed fallback, (d) `MofitTests/CameraPermissionResolverTests.swift`(신규) 4 assert, (e) `project.yml` `INFOPLIST_KEY_NSCameraUsageDescription` 카피를 프라이버시 문구("Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다.") 로 갱신해 system prompt ↔ 폴백 카드 카피 일관성 확보. `Camera/CameraManager.swift` 본체는 불변(permission 체크를 Manager 에 두면 책임 번짐 + 회귀 위험).
**트레이드오프**: (a) 권한 요청 시점이 `TrackingView` 진입 시점으로 고정되어 `HomeView` 에서 선제 요청 불가. 첫 설치 유저는 "스쿼트 시작" 탭 직전까지 카메라 권한 질문을 받지 않는다. 이는 설계 의도(reject_trigger 재트리거 방지) 이며 미래 기여자가 "선제 요청이 UX 상 낫다" 며 되돌리는 것을 방지하기 위함. (b) `TrackingView` body 가 권한 분기 만큼 커지지만 `@StateObject TrackingViewModel` 을 권한 분기 외부로 유지해 `CameraPermissionView` 래퍼 뷰 분리 안 함 — `StateObject` pass-through 지옥 및 VM lifecycle 결합을 회피(옵션 X "TrackingContent 자식 뷰 추출 + VM 을 그 안에 둠" 도 기각: 230 lines 이동 회귀 위험 대비 실익 미검증, 실제 AVFoundation console warning 이 crash/hang 으로 이어지는 증거 확인 후 마이그레이션). (c) `CameraManager.init` 은 `.denied` 상태에서도 background queue 에서 `configureSession` 을 돌리지만, `startRunning()` 가드가 `.ready` 브랜치 `.onAppear` 에 국한되어 실제 capture 는 호출되지 않음. 콘솔 warning 유무는 phase 1 구현 직후 1회 육안 확인, 실제 UX 영향 관측 시 별건 재검토.
**연계**: ADR-017(스쿼트 전용) 범위 유지. ADR-015(외부 의존성 최소화) — SPM 신규 도입 없음, AVFoundation 는 SDK 내장. ADR-018(진단 힌트 2종) 과 무충돌(진단 힌트는 `.authorized` + tracking 상태에서만 평가, 권한 분기가 앞단에서 이미 컷). iter 7 `MofitTests` 타겟(task 6) 를 그대로 재사용, 신규 target 추가 없음.
**테스트**: `CameraPermissionResolver.decide(status:)` 에 `.authorized` → `.ready`, `.denied` → `.showSettingsFallback`, `.restricted` → `.showSettingsFallback`, `.notDetermined` → `.requestInline` 4 케이스 XCTest. `@unknown default` 케이스 별도 테스트는 미작성(Apple SDK 향후 enum 추가 방어는 구현 내부 fail-closed fallback 으로 충족). SwiftUI rendering / scenePhase 전이 / `UIApplication.shared.open` / `AVCaptureDevice.requestAccess` completion 은 SDK/UIKit 의존이라 테스트 대상 아님(코드 트레이스로 대체). 실기기 QA 없음(CTO 조건 5). `xcodebuild test` 한 줄로 CI 통과.
```

**제약**:
- ADR 번호는 **정확히 ADR-019**. ADR-020 / ADR-019a 등 금지.
- 기존 ADR-018 본문은 **불변**. ADR-019 는 새 `###` 섹션으로 append 만.
- 본문 "스쿼트 이외 확장 시 … 재활용한다" 같은 일반화 문구 **금지** (CTO 조건 1).
- "곧 지원" / "로드맵" / "조만간" / "출시 예정" 미래 약속 문구 **금지** (ADR-017 준수).
- bullet 들여쓰기 2 space 금지, 대시 `-` 만.

#### 2) `docs/spec.md` — §2.8 카메라 권한 분기 신규 서브섹션

**삽입 위치**: 기존 `### 2.7 비로그인 코칭 샘플 생성` 서브섹션의 마지막 bullet(`테스트` 줄) 뒤 빈 줄 → 기존 `---` 구분선 **직전** 에 아래 §2.8 통째로 삽입. `---` 구분선 뒤에는 §3 데이터 모델이 온다.

```markdown
### 2.8 카메라 권한 분기

`TrackingView` 진입 시 `AVCaptureDevice.authorizationStatus(for: .video)` 를 3분기한다 (ADR-019).

- **판정 매핑** (`CameraPermissionResolver.decide(status:) -> CameraPermissionDecision`)
  - `.authorized` → `.ready` (기존 트래킹 뷰 + `viewModel.startSession(...)` 호출)
  - `.notDetermined` → `.requestInline` (`AVCaptureDevice.requestAccess(for: .video)` 인라인 요청 + completion 에서 decision 재계산)
  - `.denied` / `.restricted` → `.showSettingsFallback` (풀스크린 폴백 카드)
  - `@unknown default` → `.showSettingsFallback` (fail-closed, Apple SDK 향후 enum 추가 방어)
- **풀스크린 폴백 카드 카피 (고정)**
  - 타이틀: "카메라 권한이 필요해요"
  - 서브: "Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다."
  - Primary CTA: "설정에서 권한 켜기" → `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`
  - Secondary CTA: "홈으로 돌아가기" → `dismiss()` (기존 closeButton 과 동일 경로)
- **재조회 hook**
  - `.onAppear` 에서 decision 초기 계산.
  - `.onChange(of: scenePhase)` — `.active` 전이 시 재계산 (사용자가 설정 앱에서 권한 켜고 돌아오면 자동으로 `.ready` 로 진입).
  - `AVCaptureDevice.requestAccess(for: .video)` completion 에서도 `@MainActor` 컨텍스트로 decision 재계산 (`.notDetermined` → `.authorized` 전이는 scenePhase 가 안 바뀌므로 completion hook 이 유일 경로).
- **startSession 가드**
  - `viewModel.startSession(modelContext:isLoggedIn:)` 는 `decision == .ready` 브랜치 `.onAppear` 안에서만 호출. `.showSettingsFallback` / `.requestInline` 상태에서는 호출하지 않음 → AVCaptureSession.startRunning() 미호출 → 빈 검은 preview 회피.
  - `@StateObject TrackingViewModel` 는 View init 시 생성되므로 `CameraManager.init()` 의 background configureSession 는 돌지만, capture 시작이 가드되어 실제 프레임 발생 0.
- **HomeView 배지 규칙**
  - "스쿼트 시작" 버튼 아래에 `.denied` / `.restricted` 일 때만 "카메라 권한 필요" 배지 노출.
  - `.notDetermined` / `.authorized` 에서는 **배지 비노출** (CTO 조건 2 — `.notDetermined` 재트리거 방지).
  - `HomeView` 도 `.onAppear` + `.onChange(of: scenePhase)` 에서 `AVCaptureDevice.authorizationStatus(for: .video)` 재조회 → `@State var cameraStatus` 갱신.
- **프라이버시 카피 일관성**: `project.yml` `INFOPLIST_KEY_NSCameraUsageDescription` 을 "Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다." 로 갱신해 system prompt ↔ 폴백 카드 ↔ prd §4 프라이버시 섹션 3곳 문구 동기화. 사실 정합: `grep -rn 'sampleBuffer|CVPixelBuffer|CMSampleBuffer' Mofit/` 는 `Camera/CameraManager.swift`, `ViewModels/TrackingViewModel.swift`, `Services/PoseDetectionService.swift`, `Services/HandDetectionService.swift` 4-hit 전부 온디바이스 Vision 경로로만 흐름 (URLSession 호출부와 교차 0).
- **추상화 금지 원칙**: `PermissionService` / `CameraPermissionManager` / `NotificationCenter.default.addObserver(UIApplication.didBecomeActiveNotification)` 등 신규 싱글톤/추상화 금지(CTO 조건 4). 단일 뷰 `@State` + SwiftUI environment(`@Environment(\.scenePhase)`, `@Environment(\.dismiss)`) 로만 처리.
- **테스트**: `CameraPermissionResolver` 를 Foundation-only pure struct 로 추출. `MofitTests/CameraPermissionResolverTests.swift` 4 케이스(authorized/denied/restricted/notDetermined) 가 CI 통과 조건. 실기기 QA 없음(CTO 조건 5, 자동 검증 완결).
```

- 삽입 위치 주의: §2.7 마지막 bullet 뒤 빈 줄 → `### 2.8` h3 → ... → 마지막 bullet(`테스트`) 뒤 빈 줄 → 기존 `---` 구분선.
- 연속된 h3 사이에 빈 줄 1개 확보.
- §1.3 화면 목록은 **수정 금지** (새 파일 `CameraPermissionResolver.swift` 는 Views/Tracking/ 내부 헬퍼라 화면 목록 대상 아님).
- §2.4 카메라 파이프라인 / §2.5 진단 힌트 / §2.6 autosave / §2.7 코칭 샘플 본문 **전부 불변**.

#### 3) `docs/testing.md` — "현재 대상" 표현 변경 + `CameraPermissionResolver` 불릿 추가

기존 "XCTest 타겟" 섹션 내 **현재 유일 대상** 불릿:

```
- **현재 유일 대상**: `CoachingSampleGenerator` (Foundation-only, 입력 결정론적). 2 케이스 — (a) 빈 세션 + 프로필 인터폴레이션 포함 확인, (b) rep 수 인터폴레이션 포함 확인.
```

을 아래 2줄로 교체:

```
- **현재 대상**:
  - `CoachingSampleGenerator` (Foundation-only, 입력 결정론적). 2 케이스 — (a) 빈 세션 + 프로필 인터폴레이션 포함 확인, (b) rep 수 인터폴레이션 포함 확인.
  - `CameraPermissionResolver` (Foundation-only, `AVAuthorizationStatus` enum 입력 결정론적 — AVFoundation 은 SDK 내장이라 SPM 추가 없음, runtime API 호출 0). 4 케이스 — authorized → ready / denied → showSettingsFallback / restricted → showSettingsFallback / notDetermined → requestInline.
```

- "현재 유일 대상" → "현재 대상" 표현 변경 한 번만.
- 하위 불릿은 중첩(`  -` 2 space 들여쓰기) 2 줄.
- 기존 섹션의 나머지 4 불릿(파일 위치/CI 실행/외부 의존 금지/확장 정책) 은 **전부 불변**.
- 섹션 신설 금지. 설명 문단 추가 금지.

### 구현하지 말 것

- **ADR 번호 중복/혼동 금지**: ADR-019 정확히 한 개. ADR-018 업데이트 블록으로 넣지 마라 — ADR-019 는 독립 신규 ADR.
- **`docs/code-architecture.md` 수정 금지**: 이번 phase 는 docs 3개 파일만. 디렉토리 tree 업데이트는 phase 1 에서도 **하지 않는다** (새 파일 `CameraPermissionResolver.swift` 는 Views/Tracking/ 내부 헬퍼, tree 갱신 대상 아님 — 본문 tree 가 이미 `TrackingView.swift` 만 나열하고 있으며 이번 task 로 tree 확장하지 않음).
- **`docs/data-schema.md` 수정 금지**: 스키마 불변.
- **`docs/user-intervention.md` 수정 금지**: 실기기 QA 항목 추가 금지 (CTO 조건 5).
- **`docs/prd.md` · `docs/flow.md` · `docs/mission.md` 수정 금지**: 가치제안 카피 정돈은 별건. §5-11 "카메라 권한 거부 유저 동선" 문구는 그대로 유지 — 이번 phase 로 구현되지만 prd 수정은 별건 티켓 scope.
- **`README.md` · `project.yml` · `Mofit/` · `server/` · `MofitTests/` 수정 금지**: 이번 Phase 는 docs 만.
- **AnalyticsService / Mixpanel / 신규 이벤트 추가 금지**: `camera_permission_denied` 같은 유령 이벤트 문서화 금지.
- **"곧 지원" / "로드맵" / "차기 버전" / "조만간" / "출시 예정" 같은 미래 약속 문구 금지** (ADR-017 원칙 준수).
- **ADR-017 재해석 금지**: ADR-019 본문에 "ADR-017 의 '스쿼트 전용' 을 완화한다" 같은 문구 금지. ADR-019 는 ADR-017 범위 **내** 에 머문다.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0 이어야 한다.

```bash
# 1) ADR-019 신설 검증
grep -F '### ADR-019: 카메라 권한 거부 복구 플로우' docs/adr.md
grep -F 'CameraPermissionResolver.decide(status:)' docs/adr.md
grep -F "UIApplication.openSettingsURLString" docs/adr.md
grep -F 'home-workout-newbie-20s_20260424_234401' docs/adr.md
grep -F '카메라 권한을 요구하는 모든 진입점에 동일 폴백' docs/adr.md
grep -F 'CameraManager.swift 는 `AVCaptureDevice.default' docs/adr.md
# ADR-020 은 신설되지 않아야 함
! grep -E '^### ADR-020' docs/adr.md
# ADR-019 가 ADR-018 뒤에 위치
grep -B1 -A0 '^### ADR-019:' docs/adr.md | grep -qE '^$|^---|^\*\*|^조도 케이스 실기기 생략 가능'

# 2) ADR-019 일반화 문구 금지 (CTO 조건 1)
! grep -F '스쿼트 이외 확장 시' docs/adr.md
! grep -F '다른 운동에서 재활용' docs/adr.md
! grep -F '재활용한다' docs/adr.md

# 3) spec.md §2.8 신규 서브섹션
grep -F '### 2.8 카메라 권한 분기' docs/spec.md
grep -F 'CameraPermissionResolver.decide(status:) -> CameraPermissionDecision' docs/spec.md
grep -F '.authorized` → `.ready' docs/spec.md
grep -F '.denied` / `.restricted` → `.showSettingsFallback' docs/spec.md
grep -F '.notDetermined` → `.requestInline' docs/spec.md
grep -F '@unknown default' docs/spec.md
grep -F '카메라 권한이 필요해요' docs/spec.md
grep -F '영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다' docs/spec.md
grep -F 'UIApplication.openSettingsURLString' docs/spec.md
grep -F 'scenePhase' docs/spec.md
grep -F '.notDetermined` / `.authorized` 에서는 **배지 비노출**' docs/spec.md
grep -F 'NSCameraUsageDescription' docs/spec.md
grep -F 'CameraPermissionResolverTests.swift' docs/spec.md
grep -F '실기기 QA 없음' docs/spec.md
grep -F '추상화 금지' docs/spec.md

# 4) spec.md §2.7 이후 §2.8 삽입 위치 (§2.7 보존 + §2.8 추가)
grep -F '### 2.7 비로그인 코칭 샘플 생성' docs/spec.md
grep -c '^### 2\.[0-9]' docs/spec.md | grep -qE '^[89]$'  # §2.1~§2.8 (최소 8개 h3 섹션)

# 5) testing.md 현재 대상 표현 변경 + CameraPermissionResolver 불릿
grep -F '- **현재 대상**:' docs/testing.md
grep -F 'CameraPermissionResolver` (Foundation-only, `AVAuthorizationStatus' docs/testing.md
grep -F '4 케이스 — authorized → ready / denied → showSettingsFallback / restricted → showSettingsFallback / notDetermined → requestInline' docs/testing.md
grep -F 'CoachingSampleGenerator' docs/testing.md
! grep -F '- **현재 유일 대상**:' docs/testing.md

# 6) 금지 문구 미포함 (전 docs)
! grep -F '곧 지원' docs/adr.md
! grep -F '로드맵' docs/adr.md
! grep -F '조만간' docs/adr.md
! grep -F '출시 예정' docs/adr.md
! grep -F '곧 지원' docs/spec.md
! grep -F '조만간' docs/spec.md
! grep -F '출시 예정' docs/spec.md
! grep -F '곧 지원' docs/testing.md

# 7) 코드/빌드 설정 무변경
git diff --quiet HEAD -- Mofit/ MofitTests/ server/ scripts/ README.md project.yml

# 8) docs/ 변경 범위 — adr.md + spec.md + testing.md 정확히 3개
CHANGED_DOCS=$(git diff --name-only HEAD -- docs/ | sort)
EXPECTED_DOCS=$(printf 'docs/adr.md\ndocs/spec.md\ndocs/testing.md\n' | sort)
test "$CHANGED_DOCS" = "$EXPECTED_DOCS"

# 9) 금지 문서 미변경
! echo "$CHANGED_DOCS" | grep -qF 'docs/code-architecture.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/data-schema.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/user-intervention.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/flow.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/prd.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/mission.md'
```

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `tasks/7-camera-permission-recovery/index.json` 의 phase 0 status 를 `"completed"` 로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"` 로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

## 주의사항

- **ADR-019 는 신규 섹션**: ADR-018 본문을 건드리지 마라. 빈 줄 1개 후 `### ADR-019:` 로 시작하는 신규 섹션 append.
- **일반화 문구 금지 (CTO 조건 1)**: "스쿼트 이외 확장 시 이 뷰를 재활용한다" / "다른 운동에서" 같은 문구가 들어가면 AC 2 실패.
- **§2.7 과 §2.8 의 렌더링 충돌 주의**: 기존 §2.7 마지막 bullet 뒤 빈 줄 1개 확보한 뒤 §2.8 삽입. 연속된 h3 끼리 빈 줄 누락하면 markdown 렌더러에 따라 병합될 수 있다.
- **`---` 구분선 위치**: §2.7 마지막 bullet → 빈 줄 → `### 2.8` → ... → §2.8 마지막 bullet → 빈 줄 → 기존 `---` 구분선 순서. `---` 를 §2.7 과 §2.8 사이에 새로 넣지 마라.
- **testing.md 불릿 중첩 2-space 허용**: 기존 섹션의 다른 불릿은 최상위 `-` 1레벨. 이번에 추가하는 "현재 대상" 은 1레벨 `-` + 하위 `  -` 2 space 중첩 2줄. 이 섹션에서만 중첩 허용.
- **docs-diff.md 는 직접 쓰지 마라**: Phase 0 완료 후 runner(`scripts/gen-docs-diff.py`) 가 자동 생성. `tasks/7-camera-permission-recovery/docs-diff.md` 파일을 수동으로 만들지 마라.
- **기존 테스트를 깨뜨리지 마라**: docs 만 변경이라 빌드/테스트 영향 없음. 다만 `Mofit/` / `MofitTests/` 파일을 실수로 건드리면 AC 7 실패.
- **git status 클린 상태 시작**: dirty 면 error 기록 후 중단.
- **ADR 번호 유지**: ADR-019 는 ADR-018 다음 연속 번호. 건너뛰거나 ADR-020 으로 가지 마라.
- **`docs/testing.md` 상단 3줄 원칙 + 9행 중요 줄 불변**: 새 불릿은 기존 "XCTest 타겟" 섹션 내부의 "현재 유일 대상" 교체로만. 섹션 전체 구조 변경 금지.
- **§1.3 화면 목록 수정 금지**: `CameraPermissionResolver` 는 화면이 아니라 헬퍼. 별도 화면 항목 추가하지 마라.
- **prd §4 프라이버시 / §5-11 카메라 권한 거부 문구는 불변**: §5-11 "카메라 권한 거부 유저 동선" 이 이번 task 로 해소되지만 prd 수정은 별건 스코프 (iteration requirement.md 에 "카메라 권한 거부 복구 플로우 없음" 언급이 차기 iter 시뮬 개선 포인트에서 제거되는지가 측정 지표).
