# Phase 1: tap-impl

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다 (Phase 0이 이미 커밋되어 있어야 한다).

```bash
git status --porcelain -- docs/ Mofit/ project.yml
```

출력되는 파일이 있으면 working tree가 더럽다는 뜻이다. 진행하지 말고 `tasks/2-tap-fallback/index.json`의 phase 1 status를 `"error"`로 변경, `error_message`에 `dirty working tree before phase 1`로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/spec.md` (특히 Phase 0에서 갱신된 §2.1 상태머신)
- `docs/adr.md` (특히 ADR-001 Apple Vision, ADR-007 다크모드 고정, ADR-009 MVP 제외 목록)
- `docs/code-architecture.md` (MVVM · `Views/Tracking/` · `ViewModels/TrackingViewModel` 위상)
- `docs/testing.md` (테스트 정책 — mock 접착제 테스트 금지, 커버리지 숫자 목표 없음, 모듈 구현 직후 테스트 작성. **단 이 phase는 XCTest target 신설 금지** — 기존 전례 `tasks/1-coaching-samples/phase1.md` AC #11 유지.)
- `docs/user-intervention.md`
- `tasks/2-tap-fallback/docs-diff.md` (Phase 0 docs 변경 실제 diff — runner 자동 생성)
- `iterations/3-20260424_162818/requirement.md` (iteration 원문 읽기 전용. 특히 §채택된요구사항 → §구현스케치 1~5번, §CTO 승인 조건부 4개)

그리고 이전 phase의 작업물과 기존 코드를 반드시 확인하라:

- `docs/spec.md` — Phase 0이 수정한 §2.1 다이어그램
- `Mofit/Views/Tracking/TrackingView.swift` — 이번 phase 수정 대상. 특히:
  - L19-40 root `GeometryReader > ZStack` (`.onTapGesture` 부착 지점)
  - L41-52 `.onAppear` / `.onDisappear` / `.onChange` 체인 (`.contentShape` + `.onTapGesture` 는 **이 체인보다 앞에** 둔다)
  - L81-90 `idleOverlay` (서브카피 리터럴 교체 지점)
  - L98-133 `trackingOverlay` — 특히 **L129-131 중앙 단일 `Text("\(viewModel.currentReps)")`** 가 교체 대상. 상단 L99-127 헤더 VStack(세트/시간)은 **건드리지 마라.**
  - L179-192 `stopButton` — 빨간 `Button`, `stopSession`+`showConfetti=true`+`dismiss`. 이번 phase에서 **건드리지 마라.**
  - L164-177 `closeButton` — X `Button`, `stopSession`+`dismiss`. 이번 phase에서 **건드리지 마라.**
- `Mofit/ViewModels/TrackingViewModel.swift` — 이번 phase 수정 대상. 특히:
  - L157-167 `processFrame` (`handlePalmDetection` 호출부 — 수정 불필요)
  - L169-186 `handlePalmDetection` (내부의 `triggerPalmAction()` 호출부가 rename 대상)
  - L188-197 `triggerPalmAction` (rename 대상)
  - L199-226 `startCountdown`, L246-256 `completeSet` (`triggerSetAction`이 호출하는 경로 — 수정 불필요)
- `Mofit/Utils/Theme.swift` — 기존 상수 (`Theme.neonGreen`). **신규 색상 정의 금지.**
- `project.yml` — xcodegen 설정. `Mofit/**/*.swift` 글롭 기반이라 신규 `.swift` 파일 자동 편입. `project.yml` 자체는 수정 금지.

이전 phase에서 만들어진 문서와 기존 코드를 꼼꼼히 읽고, spec.md §2.1의 상태머신 확장을 코드로 옮긴다는 점을 명심하라.

## 작업 내용

### 대상 파일

1. **수정**: `Mofit/ViewModels/TrackingViewModel.swift` (rename + `handleScreenTap` 신설 + 햅틱)
2. **수정**: `Mofit/Views/Tracking/TrackingView.swift` (`.contentShape` + `.onTapGesture` + idle 서브카피 + tracking caption)
3. **신규**: `tasks/2-tap-fallback/qa-checklist.md`

신규 `.swift` 파일 생성 금지(파일 분리 금지). MofitTests 디렉토리 생성 금지.

### 목적

손바닥 인식 실패로 `idle`에서 카운트다운이 시작되지 않아 사용자가 3분 만에 앱을 닫는 이탈 경로를 차단한다. 진입 즉시 서브카피로 탭 경로를 인지시키고, ZStack 전체에 `.onTapGesture`를 부착해 손바닥 1초 경로와 병렬로 동일 결과(`startCountdown` / `completeSet`)를 내도록 한다. `tracking` 상태에서는 0회 세트 조기 종료를 막기 위해 `currentReps > 0` 가드를 걸고, 사용자가 탭을 인지할 수 있도록 햅틱 피드백을 발생시킨다.

### 구현 요구사항

#### 1) `Mofit/ViewModels/TrackingViewModel.swift`

##### 1-a) import 추가

파일 상단 기존 import (L1-L5: `AVFoundation`, `Combine`, `Foundation`, `SwiftData`, `Vision`) 아래에 `import UIKit` 한 줄 추가. 순서는 알파벳 순 유지(`SwiftData`와 `UIKit`과 `Vision` 사이).

##### 1-b) `triggerPalmAction()` → `triggerSetAction()` rename

L188-197 `private func triggerPalmAction()` 의 함수명만 `triggerSetAction`으로 rename. 내부 구현(switch state / .idle → startCountdown() / .tracking → completeSet() / default break)은 **한 줄도 바꾸지 마라.** 호출부는 L181 (`handlePalmDetection` 내부)의 `self.triggerPalmAction()` 단 1곳. 이것도 `self.triggerSetAction()`으로 같이 갱신.

의미: palm과 tap이 공통 진입점을 사용함을 코드에서 드러낸다(CTO 조건부 #5).

##### 1-c) `handleScreenTap()` 신규 public 메서드

파일 어디에 추가해도 무방하나 `triggerSetAction()` 직전 또는 직후가 자연스럽다. 시그니처와 로직:

```swift
func handleScreenTap() {
    switch state {
    case .idle:
        triggerSetAction()
    case .tracking:
        guard currentReps > 0 else { return }   // 0회 세트 조기 종료 방지 (CTO 조건부 #2)
        triggerHapticFeedback()                 // 사용자 탭 ack (CTO 조건부 #1)
        triggerSetAction()
    case .countdown, .setComplete:
        return                                   // noop
    }
}

private func triggerHapticFeedback() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
}
```

규칙:
- `handleScreenTap` 접근 제어는 internal(default). View에서 호출 가능해야 함. `private` 금지.
- `triggerHapticFeedback`는 `private`.
- `@MainActor` 어노테이션은 클래스 레벨에 이미 걸려 있으므로 개별 메서드에 덧붙이지 마라.
- switch는 위 4케이스(idle / tracking / countdown / setComplete) 전부 명시해 컴파일러가 exhaustiveness 검증하도록 한다. default 대신 `case .countdown, .setComplete` 로 명시. (state enum 변경 시 컴파일 에러로 표출 → 미래 회귀 방지.)
- 기존 `handlePalmDetection`(L169-186), `triggerSetAction`(= 구 `triggerPalmAction`), `startCountdown`, `completeSet` 의 구현은 **한 줄도 수정하지 마라.** 이번 변경은 "rename 1곳 + public 핸들러 추가 + private 헬퍼 추가" 3개뿐이다.

#### 2) `Mofit/Views/Tracking/TrackingView.swift`

##### 2-a) ZStack root에 `.contentShape(Rectangle())` + `.onTapGesture` 부착

현재 L19-52 구조:

```swift
GeometryReader { geometry in
    ZStack {
        // ... CameraPreviewView / overlayContent / jointOverlay / closeButton / stopButton ...
    }
    .onAppear { ... }
    .onDisappear { ... }
    .onChange(of: geometry.size) { ... }
}
```

수정 후 구조:

```swift
GeometryReader { geometry in
    ZStack {
        // ... 기존 내용 그대로 ...
    }
    .contentShape(Rectangle())
    .onTapGesture { viewModel.handleScreenTap() }
    .onAppear { ... }
    .onDisappear { ... }
    .onChange(of: geometry.size) { ... }
}
```

규칙:
- `.contentShape(Rectangle())`는 `.onAppear` 체인보다 **앞에** 둔다. `.onTapGesture`는 `.contentShape` 직후.
- ZStack 내부 `CameraPreviewView.ignoresSafeArea()` / `overlayContent` / `jointOverlay` / `closeButton` / `stopButton` 순서·구조는 **한 줄도 바꾸지 마라.** `jointOverlay`는 기존 `.allowsHitTesting(false)` 그대로 유지.
- `closeButton` / `stopButton`은 SwiftUI `Button`이므로 내부 hit-test가 우선 처리된다. 별도 `.allowsHitTesting` / `.highPriorityGesture` / exclude 로직을 **추가하지 마라.**

##### 2-b) `idleOverlay` 서브카피 교체

현재 L81-90:

```swift
private var idleOverlay: some View {
    Text("손바닥을 보여주세요")
        // modifiers...
}
```

수정:

```swift
private var idleOverlay: some View {
    Text("손바닥을 보여주거나 화면을 탭하세요")
        // 기존 modifiers 그대로 (font/fontWeight/foregroundColor/padding/background/cornerRadius)
}
```

- 리터럴 `"손바닥을 보여주세요"`는 이 파일 전체에서 사라져야 한다.
- 폰트·패딩·배경·코너 반경은 기존값 그대로. 스타일 수정 금지.
- `AttributedString` / markdown 강조 / 별도 `Text("화면을 탭")` 분리 금지. 한 줄 plain Text.

##### 2-c) `trackingOverlay` — 중앙 큰 숫자 → VStack 교체

**정확한 수정 위치**: L98-133 `trackingOverlay` 의 **바깥쪽 ZStack** 내부, 현재 L129-131의 중앙 단일 `Text("\(viewModel.currentReps)")` (100pt, `Theme.neonGreen`)를 아래 `VStack`으로 교체한다. 상단 L99-127의 헤더 `VStack { HStack { 세트 / 시간 } Spacer() }`는 **건드리지 마라.** 새 VStack도 여전히 바깥쪽 ZStack의 센터에 떠 있어야 한다.

교체 후:

```swift
VStack(spacing: 8) {
    Text("\(viewModel.currentReps)")
        .font(.system(size: 100, weight: .bold))
        .foregroundColor(Theme.neonGreen)
    Text("끝낼 땐 화면을 탭하거나 손바닥을 보여주세요")
        .font(.caption)
        .foregroundColor(.white)
        .opacity(0.7)
}
```

규칙:
- 큰 숫자의 font/size/weight/foregroundColor 변경 금지. 기존값 그대로.
- caption은 `.font(.caption)` + `.foregroundColor(.white)` + `.opacity(0.7)`. 다른 색상/opacity 값 금지 (CTO 조건부 #3: 100pt 숫자 가독성 보존).
- VStack spacing 8 고정. 다른 spacing 값 금지.
- caption 리터럴은 정확히 `끝낼 땐 화면을 탭하거나 손바닥을 보여주세요`. 띄어쓰기·조사 변형 금지.

#### 3) `tasks/2-tap-fallback/qa-checklist.md` 신규

무인 세션은 실기기 카메라 세션을 돌릴 수 없다. 릴리즈 빌드 전 사용자가 실기기/시뮬레이터에서 아래를 직접 확인한다. 파일 내용 전체를 아래 그대로 작성 (앞뒤 공백·줄바꿈까지).

```markdown
# QA Checklist — task 2 (tap-fallback)

무인 세션에서는 실기기 카메라 세션이 불가능하다. 릴리즈 빌드 전 사용자가 실기기에서 아래를 직접 확인한다.

- [ ] 1. idle 상태 진입 시 "손바닥을 보여주거나 화면을 탭하세요" 서브카피가 즉시 노출된다 (5초 대기 배너 아님).
- [ ] 2. idle 상태에서 화면 탭 → 5초 카운트다운이 시작된다 (손바닥 경로와 동일한 결과).
- [ ] 3. **손바닥 경로 회귀** — idle에서 손바닥 1초 유지 → 카운트다운 시작. 변경 전과 동일. [조건부 #4]
- [ ] 4. tracking 상태에서 rep이 0회인 상태로 화면 탭 → 아무 일도 일어나지 않는다 (noop, 세트 조기 종료 없음).
- [ ] 5. tracking 상태에서 rep 1회 이상 쌓인 뒤 화면 탭 → 햅틱 피드백(medium impact) + setComplete 오버레이 → 1초 후 다음 카운트다운. [조건부 #1, #2]
- [ ] 6. **손바닥 경로 회귀** — tracking 상태 rep 1회 이상에서 손바닥 1초 유지 → setComplete. [조건부 #4]
- [ ] 7. tracking 상태에서 중앙 큰 숫자 아래 caption "끝낼 땐 화면을 탭하거나 손바닥을 보여주세요"가 숫자 가독성을 해치지 않는 정도로 희미하게 보인다 (`.caption` + `.opacity(0.7)`).
- [ ] 8. tracking 중 하단 빨간 stopButton 탭 → 세션 전체 종료 + 홈 복귀 + 폭죽 연출 (회귀 확인). 세트 종료 햅틱/카운트다운 재진입 없음.
- [ ] 8-1. 탭이 ZStack root에 부착돼 있어도 closeButton(X) 영역 탭 → closeButton 액션(세션 종료 + 홈 복귀)만 트리거되고 handleScreenTap 경로는 실행되지 않는다.
- [ ] 8-2. stopButton도 동일. 빨간 버튼 탭 = 세션 종료 + 폭죽만 발동, 세트 종료 햅틱/카운트다운 재진입 없음.
- [ ] 9. 상단 좌측 closeButton(X) 탭 → 세션 종료 + 홈 복귀 (회귀 확인).
- [ ] 10. countdown 진행 중(숫자가 5→4→3 줄어드는 동안) 화면 탭 → 아무 반응 없음.
- [ ] 11. setComplete 1초 표시 중 화면 탭 → 아무 반응 없음. 자동으로 다음 countdown 진입.
- [ ] 12. 다크 모드(ADR-007) 유지, 라이트 모드 전환 시에도 화면 톤 그대로.

결과는 각 항목 체크 + 실패 시 메모. 이 파일은 task 산출물로 git에 커밋된다.
```

### 하지 말아야 할 것

- **XCTest target 신설 금지.** `MofitTests` 디렉토리 생성 금지. testing.md 원칙 + 지난 task 1 전례 유지. `test ! -d MofitTests` AC 유지.
- **신규 Swift 파일 생성 금지.** `TapGestureView.swift` / `ScreenTapHandler.swift` 같은 파일 분리 금지.
- **`Mofit/Models/**`, `Mofit/Services/**`, `Mofit/Camera/**`, `Mofit/Config/**` 수정 금지.** 이번 변경은 View 1개 + ViewModel 1개 한정.
- **`closeButton` / `stopButton` 구현 수정 금지.** hit-test 우선순위에 의존하는 구조이므로 Button을 일반 View로 바꾸면 회귀. 라벨/크기/색/위치 모두 불변.
- **`jointOverlay`의 `.allowsHitTesting(false)` 제거 금지.** 제거 시 관절 포인트 위 탭이 막힘.
- **`handlePalmDetection`, `startCountdown`, `completeSet` 로직 수정 금지.** 이번 변경은 rename 1곳 + 신규 메서드 2개 추가가 전부.
- **`triggerPalmAction` 호출부 누락 금지.** rename 후 `self.triggerPalmAction()` 문자열이 파일 어디에도 남으면 안 된다(컴파일 에러로 표출됨).
- **디바운스 타이머 / "rep 변화 없음 타이머" 추가 금지** (CTO 조건부 #3 — 과설계 방지).
- **5초 배너 / fade-in 애니메이션 / 하이라이트 효과 추가 금지.** 서브카피는 즉시 노출.
- **Analytics 이벤트 추가 금지** (예: `.screenTapped`, `.setCompletedByTap`). `AnalyticsService.swift` 불변.
- **햅틱 스타일 변경 금지.** `UIImpactFeedbackGenerator(style: .medium)` 고정. light/heavy/rigid/soft 금지.
- **`idle` 서브카피에서 "화면을 탭" 부분 강조 금지.** AttributedString / neonGreen 색상 적용 / 별도 Text 분할 금지. plain Text 한 줄.
- **`docs/`, `server/`, `project.yml`, `scripts/`, `iterations/`, `tasks/0-exercise-coming-soon/`, `tasks/1-coaching-samples/` 수정 금지.** 이번 phase는 Mofit/Views/Tracking/TrackingView.swift + Mofit/ViewModels/TrackingViewModel.swift + tasks/2-tap-fallback/qa-checklist.md 단 3개 파일.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0이어야 한다.

```bash
# 1) 프로젝트 재생성 (글롭 기반이라 실제로 신규 파일 없음이지만 일관성 유지)
xcodegen generate

# 2) 빌드 성공 (시뮬레이터용, 코드 사이닝 off)
xcodebuild \
  -scheme Mofit \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -80

# 3) 신규 리터럴 존재 (idle 서브카피 + tracking caption)
grep -F "손바닥을 보여주거나 화면을 탭하세요" Mofit/Views/Tracking/TrackingView.swift
grep -F "끝낼 땐 화면을 탭하거나 손바닥을 보여주세요" Mofit/Views/Tracking/TrackingView.swift

# 4) .contentShape + .onTapGesture + handleScreenTap 연결
grep -F ".contentShape(Rectangle())" Mofit/Views/Tracking/TrackingView.swift
grep -F "viewModel.handleScreenTap()" Mofit/Views/Tracking/TrackingView.swift

# 5) ViewModel rename 적용 (기존 심볼 제거 + 새 심볼 존재)
! grep -F "triggerPalmAction" Mofit/ViewModels/TrackingViewModel.swift
grep -F "triggerSetAction" Mofit/ViewModels/TrackingViewModel.swift
grep -F "func handleScreenTap" Mofit/ViewModels/TrackingViewModel.swift
grep -F "UIImpactFeedbackGenerator" Mofit/ViewModels/TrackingViewModel.swift
grep -F "import UIKit" Mofit/ViewModels/TrackingViewModel.swift

# 6) currentReps > 0 가드 존재 (CTO 조건부 #2)
grep -F "currentReps > 0" Mofit/ViewModels/TrackingViewModel.swift

# 7) 기존 리터럴 "손바닥을 보여주세요" (끝따옴표 포함 정확 문자열)가 파일 어디에도 없음
! grep -F '"손바닥을 보여주세요"' Mofit/Views/Tracking/TrackingView.swift

# 8) View에서 handleScreenTap 호출이 정확히 1회 (중복 부착 방지)
test "$(grep -c 'viewModel.handleScreenTap()' Mofit/Views/Tracking/TrackingView.swift)" -eq 1

# 9) 금지 스코프 미변경
git diff --quiet HEAD -- Mofit/Models/
git diff --quiet HEAD -- Mofit/Services/
git diff --quiet HEAD -- Mofit/Camera/
git diff --quiet HEAD -- Mofit/Config/
git diff --quiet HEAD -- server/
git diff --quiet HEAD -- project.yml scripts/ iterations/ docs/
git diff --quiet HEAD -- tasks/0-exercise-coming-soon/
git diff --quiet HEAD -- tasks/1-coaching-samples/

# 10) 신규 파일 금지 경계 — 파일 분리 / XCTest 없음
test ! -d MofitTests
test ! -f Mofit/Views/Tracking/TapGestureView.swift
test ! -f Mofit/Views/Tracking/ScreenTapHandler.swift

# 11) QA 체크리스트 산출물 존재 + 필수 항목 포함
test -f tasks/2-tap-fallback/qa-checklist.md
grep -F "손바닥 경로 회귀" tasks/2-tap-fallback/qa-checklist.md
grep -F "조건부 #1" tasks/2-tap-fallback/qa-checklist.md
grep -F "조건부 #2" tasks/2-tap-fallback/qa-checklist.md
grep -F "조건부 #4" tasks/2-tap-fallback/qa-checklist.md
```

xcodebuild 출력 말미에 `** BUILD SUCCEEDED **` 가 찍혀야 한다.

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/2-tap-fallback/index.json`의 phase 1 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

xcodebuild가 디스크/시뮬레이터 런타임 부재 등으로 실패하면, `xcodebuild -showsdks | grep iphonesimulator` 로 사용 가능한 SDK를 확인하고 `-sdk` 값을 조정하라. 그래도 해결이 안 되면 `-destination 'generic/platform=iOS'` 로 전환을 시도하되, 실패 로그 전체를 `error_message`에 기록하라.

## 주의사항

- **리터럴은 글자까지 동일하게.** idle 서브카피 `손바닥을 보여주거나 화면을 탭하세요`, tracking caption `끝낼 땐 화면을 탭하거나 손바닥을 보여주세요`. 띄어쓰기·조사 변형 금지. AC grep이 정확 문자열 기준이라 실패한다.
- **`.contentShape(Rectangle())` 누락 시 투명 배경 영역 탭이 안 먹힌다.** `.onTapGesture` 직전에 반드시 부착. 둘의 순서 뒤집지 마라.
- **rename은 `triggerPalmAction` 심볼만. 다른 "Palm" 표현(`handlePalmDetection`, `palmDetectionStartTime`)은 건드리지 마라.** 손바닥 감지 자체 로직이므로 이름 유지가 맞다.
- **`handleScreenTap`의 switch는 exhaustive.** `case .idle` / `case .tracking` / `case .countdown, .setComplete` 네 케이스 명시. `default` 사용 금지. state enum에 새 케이스가 추가될 때 컴파일 에러로 잡히게 한다.
- **햅틱은 `.tracking` 분기에서만.** `.idle` 분기에는 햅틱 없음 (countdown 5초가 시각 피드백 역할).
- **`currentReps > 0` 가드는 `.tracking` 분기에만.** `.idle`에서는 rep 값에 의존하지 않는다.
- **햅틱 호출은 `triggerSetAction()` 호출 **이전**에.** 시각 피드백(setComplete 오버레이)보다 햅틱이 먼저 도달해야 탭 ack가 명확.
- **`Theme`에 신규 색상 정의 금지.** caption `foregroundColor(.white)` + `.opacity(0.7)`는 SwiftUI 기본 흰색 사용. `Theme.textSecondary` 같은 기존 상수 사용도 금지 (이번 caption은 카메라 프리뷰 위 흰색 유지).
- **다크모드 고정 유지** (ADR-007). 라이트 모드 대응 코드 추가 금지.
- **기존 테스트를 깨뜨리지 마라.** (현재 `MofitTests` target 없음. 서버 쪽 Node 테스트는 서버 미변경이라 무관.)
- **Analytics 이벤트 추가 금지.** 샘플 노출률/세트 종료 방식 측정 유혹에 넘어가지 마라. 이번 scope 밖.
- **git status --porcelain이 clean한 상태에서 시작.** dirty면 error 기록 후 중단.
