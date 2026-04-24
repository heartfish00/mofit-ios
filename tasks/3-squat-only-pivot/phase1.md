# Phase 1: squat-only-code

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다 (Phase 0 이 이미 커밋되어 있어야 한다).

```bash
git status --porcelain -- docs/ Mofit/ project.yml README.md
```

출력되는 파일이 있으면 working tree 가 더럽다는 뜻이다. 진행하지 말고 `tasks/3-squat-only-pivot/index.json` 의 phase 1 status 를 `"error"`로 변경, `error_message` 에 `dirty working tree before phase 1` 로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/spec.md` (§1.3 화면 목록 — Phase 0 에서 `ExercisePickerView` 행이 제거됨. §2 상태머신은 무관)
- `docs/prd.md` (§홈탭 — Phase 0 에서 "스쿼트 시작" 버튼으로 정리됨)
- `docs/adr.md` (특히 ADR-017 — 이번 phase 의 설계 원전. ADR-008/ADR-016 은 SUPERSEDED 이나 본문은 그대로)
- `docs/code-architecture.md` (§디렉토리 구조 Views/Home 블록이 `HomeView.swift` 하나만 남도록 갱신됨)
- `docs/testing.md` (**신규 XCTest target 금지**. 이번 phase 는 build + grep 으로 AC 커버)
- `docs/user-intervention.md`
- `tasks/3-squat-only-pivot/docs-diff.md` (Phase 0 docs 변경 실제 diff — runner 자동 생성)
- `iterations/4-20260424_193445/requirement.md` (iteration 원문 읽기 전용. 특히 §채택된 요구사항, §구현 스케치 1~8번, §CTO 승인 조건부 1~4)

그리고 이전 phase 의 작업물과 기존 코드를 반드시 확인하라:

- `Mofit/Views/Home/ExercisePickerView.swift` — **파일 삭제 대상.** 내용 확인 후 삭제.
- `Mofit/Views/Home/HomeView.swift` — 수정 대상. 특히:
  - 상태 프로퍼티: `@State selectedExerciseName`, `exerciseNameToType` static dict, `selectedExerciseType` computed, `@State showExercisePicker` — 전부 제거
  - `.sheet(isPresented: $showExercisePicker) { ExercisePickerView(...) }` — 제거
  - `.fullScreenCover(isPresented: $showTracking) { TrackingView(exerciseType: selectedExerciseType, ...) }` — `exerciseType: "squat"` 로 하드코딩
  - `exerciseSelector` 뷰 var + 그 호출부(`exerciseSelector.padding(.top, 32)`) — 제거
  - `startButton` 내부 `Text("운동 시작")` — `Text("스쿼트 시작")` 로 교체
  - `todaySummaryCard` 내부 `summaryItem(value: "\(todayTotalReps)", label: "rep")` — `label: "스쿼트"` 로 교체
- `Mofit/Views/Tracking/TrackingView.swift` — **수정 금지.** `init(exerciseType: String, showConfetti:)` 시그니처 불변 (CTO 조건부 #1).
- `Mofit/ViewModels/TrackingViewModel.swift` — **수정 금지.** `init(exerciseType: String = "squat", ...)` + 내부 `switch exerciseType` 분기 불변 (CTO 조건부 #1).
- `Mofit/Services/PushUpCounter.swift`, `Mofit/Services/SitUpCounter.swift`, `Mofit/Services/SquatCounter.swift`, `Mofit/Services/ExerciseCounter.swift` — **전부 수정 금지** (CTO 조건부 #1).
- `project.yml` — 수정 금지. 글롭 기반(`Mofit/**`)이라 파일 삭제만으로 재생성 시 자동 반영됨.

이전 phase 의 문서가 선언한 "스쿼트 전용 포지셔닝"(ADR-017)을 실코드로 옮긴다는 점을 명심하라. 목표는 **View 레이어 한정 삭제/문자열 교체**. 내부 판정 로직은 보존.

## 작업 내용

### 대상 파일

1. **삭제**: `Mofit/Views/Home/ExercisePickerView.swift`
2. **수정**: `Mofit/Views/Home/HomeView.swift` (상태 제거 + 뷰 var 제거 + 문자열 리터럴 교체)
3. **재생성**: `Mofit.xcodeproj/project.pbxproj` (xcodegen 자동)

신규 `.swift` 파일 생성 금지. `project.yml` 편집 금지. `MofitTests/` 디렉토리 생성 금지.

### 목적

ExercisePickerView 드롭다운으로 노출되던 푸쉬업/싯업 "준비중" UI 를 제거해, "홈트 기대 설치 → 3일 안에 스쿼트 전용임 인지 → 무료 스쿼트 카운터로 전환" 이탈 경로(iter 4 keyman 판정 실패 사유) 를 원천 차단한다. 사용자 표면에서는 **"스쿼트 시작" 단일 CTA** 만 노출되도록 정돈한다.

### 구현 요구사항

#### 1) `Mofit/Views/Home/ExercisePickerView.swift` 파일 삭제

```bash
git rm Mofit/Views/Home/ExercisePickerView.swift
```

- 파일 삭제 후 다른 파일에서 `ExercisePickerView` 심볼 참조가 남아있으면 컴파일 에러가 발생한다. HomeView.swift 의 참조(2-a, 2-b) 도 같은 phase 에서 제거.
- 파일 삭제에는 `git rm` 을 사용한다. `rm` 만 호출하면 working tree 에서만 사라지고 git index 에는 남을 수 있다.

#### 2) `Mofit/Views/Home/HomeView.swift` 수정

##### 2-a) 상태 프로퍼티 제거

현재 L10~23 영역 (상태 선언 블록):

**기존**:

```swift
    @State private var selectedExerciseName = "스쿼트"
    @State private var serverSessions: [ServerSession] = []
    @State private var isLoadingServerData = false

    private static let exerciseNameToType: [String: String] = [
        "스쿼트": "squat",
        "푸쉬업": "pushup",
        "싯업": "situp",
    ]

    private var selectedExerciseType: String {
        Self.exerciseNameToType[selectedExerciseName] ?? "squat"
    }
    @State private var showExercisePicker = false
    @State private var showProfileEdit = false
    @State private var showTracking = false
    @State private var showConfetti = false
```

**신규** (정확히 아래 블록으로 교체):

```swift
    @State private var serverSessions: [ServerSession] = []
    @State private var isLoadingServerData = false

    @State private var showProfileEdit = false
    @State private var showTracking = false
    @State private var showConfetti = false
```

규칙:
- `selectedExerciseName`, `exerciseNameToType`, `selectedExerciseType`, `showExercisePicker` 4개 심볼이 파일 전체에서 사라져야 한다.
- 그 외 프로퍼티 (`@Environment modelContext`, `@EnvironmentObject authManager`, `@Query profiles`, `@Query sessions`, `serverSessions`, `isLoadingServerData`, `showProfileEdit`, `showTracking`, `showConfetti`) 는 전부 유지. 접근 제어자 / 기본값 / 선언 순서 임의 변경 금지.

##### 2-b) `.sheet(isPresented: $showExercisePicker)` 블록 제거

현재 L111~115 영역:

**기존**:

```swift
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView(selectedExerciseName: $selectedExerciseName)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
```

**삭제.** 이 `.sheet` 모디파이어 전체 5 줄을 지운다. 다른 모디파이어(`.fullScreenCover(isPresented: $showProfileEdit)`, `.fullScreenCover(isPresented: $showTracking)`, `.task`, `.onChange` 등) 순서는 불변.

##### 2-c) `.fullScreenCover` → TrackingView exerciseType 하드코딩

현재 L120~123 영역:

**기존**:

```swift
        .fullScreenCover(isPresented: $showTracking) {
            TrackingView(exerciseType: selectedExerciseType, showConfetti: $showConfetti)
                .environmentObject(authManager)
        }
```

**신규**:

```swift
        .fullScreenCover(isPresented: $showTracking) {
            TrackingView(exerciseType: "squat", showConfetti: $showConfetti)
                .environmentObject(authManager)
        }
```

- `TrackingView` 의 `init(exerciseType: String, showConfetti: Binding<Bool>)` 시그니처는 불변. 호출부에서 문자열 상수 `"squat"` 만 넘긴다 (CTO 조건부 #1).
- `TrackingViewModel` 내부 `switch exerciseType` 분기는 기존에도 `"squat"` / `"pushup"` / `"situp"` 중 하나를 받도록 설계됨. 이번 변경은 호출 도메인 축소뿐이므로 Counter 자산은 그대로 유지된다.

##### 2-d) `exerciseSelector` 뷰 var 제거 + VStack 내부 호출 제거

###### body 내부 호출 제거 (현재 L83~86 영역)

**기존**:

```swift
                    VStack(spacing: 24) {
                        exerciseSelector
                            .padding(.top, 32)

                        startButton
                            .padding(.horizontal)

                        todaySummaryCard
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
```

**신규**:

```swift
                    VStack(spacing: 24) {
                        startButton
                            .padding(.horizontal)
                            .padding(.top, 32)

                        todaySummaryCard
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
```

- `exerciseSelector` 호출 + 그 `.padding(.top, 32)` 줄이 사라지는 대신, **`startButton` 에 `.padding(.top, 32)`** 를 부착해 원래 카드와의 시각적 세로 간격을 보존한다.
- `VStack(spacing: 24)`, `todaySummaryCard` 의 `.padding(.horizontal)`, 바깥 `.padding(.bottom, 32)` 는 불변.

###### `exerciseSelector` 뷰 var 정의 제거 (현재 L181~200)

**기존**:

```swift
    private var exerciseSelector: some View {
        Button {
            showExercisePicker = true
        } label: {
            HStack {
                Text(selectedExerciseName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Image(systemName: "chevron.down")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
        }
    }
```

**삭제.** 이 `exerciseSelector` 뷰 var 정의 전체를 지운다. 앞뒤 빈 줄도 이웃 뷰 var 와 충돌 없게 정돈.

##### 2-e) `startButton` 라벨 교체 (현재 L202~215)

**기존**:

```swift
    private var startButton: some View {
        Button {
            showTracking = true
        } label: {
            Text("운동 시작")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.darkBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Theme.neonGreen)
                .cornerRadius(16)
        }
    }
```

**신규** (Text 리터럴만 `"스쿼트 시작"` 으로 교체. 그 외 모디파이어 불변):

```swift
    private var startButton: some View {
        Button {
            showTracking = true
        } label: {
            Text("스쿼트 시작")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.darkBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Theme.neonGreen)
                .cornerRadius(16)
        }
    }
```

##### 2-f) `todaySummaryCard` rep 라벨 교체 (현재 L242~248 중 1줄)

`todaySummaryCard` 내부 HStack 의 3개 `summaryItem` 중 두 번째:

**기존**:

```swift
                    summaryItem(value: "\(todayTotalReps)", label: "rep")
```

**신규**:

```swift
                    summaryItem(value: "\(todayTotalReps)", label: "스쿼트")
```

- 첫 번째 (`label: "세트"`) 와 세 번째 (`label: "시간"`) 는 불변.
- `todayTotalReps` computed 프로퍼티는 그대로 유지 (이름 변경 금지).

##### 2-g) 그 외 HomeView 구조 불변

- `topBar`, `todaySummaryCard`, `summaryItem`, `formatDuration`, `loadServerData`, `parseISO8601Date`, `todaySessions`, `todayServerSessions`, `todayTotalSets`, `todayTotalReps`, `todayTotalDuration`, `hasTodaySessions` 는 전부 유지. 로직/시그니처 변경 금지.
- 파일 하단의 `ConfettiView` / `ConfettiParticle` 정의는 불변.

#### 3) xcodeproj 재생성

```bash
xcodegen generate
```

- 글롭 기반이라 삭제된 `ExercisePickerView.swift` 가 자동으로 pbxproj 에서 빠진다.
- `project.yml` 는 수정하지 않는다.

### 하지 말아야 할 것

- **XCTest target 신설 금지.** `MofitTests/` 디렉토리 생성 금지. `docs/testing.md` 원칙 + 직전 task 0/1/2 전례 유지. 신규 분기/로직 없음.
- **신규 Swift 파일 생성 금지.** ExercisePickerView 삭제를 대체하는 별도 헬퍼/뷰 분리 금지.
- **`Mofit/ViewModels/TrackingViewModel.swift` 수정 금지** (CTO 조건부 #1). `exerciseType` 파라미터, `switch exerciseType` 분기, 저장 시 `exerciseType` 필드 기록 등 모든 분기를 그대로 유지.
- **`Mofit/Views/Tracking/TrackingView.swift` 수정 금지.** `init(exerciseType: String, showConfetti: Binding<Bool>)` 시그니처 불변.
- **`Mofit/Services/PushUpCounter.swift`, `Mofit/Services/SitUpCounter.swift`, `Mofit/Services/SquatCounter.swift`, `Mofit/Services/ExerciseCounter.swift` 수정 금지** (CTO 조건부 #1). 푸쉬업/싯업 확장 시 되살릴 자산.
- **`Mofit/Models/**`, `Mofit/Camera/**`, `Mofit/Config/**`, `Mofit/Utils/**`, `Mofit/App/**`, `Mofit/Services/*` (Counter 제외), `Mofit/ViewModels/**` 모두 수정 금지.** 이번 phase 는 `Mofit/Views/Home/HomeView.swift` 1개 편집 + `ExercisePickerView.swift` 1개 삭제가 전부 (+ xcodeproj 재생성).
- **`Mofit/Views/Records/**`, `Mofit/Views/Coaching/**`, `Mofit/Views/Onboarding/**`, `Mofit/Views/Profile/**` 수정 금지.**
- **미래 약속 문구 금지** (CTO 조건부 #3). 코드 주석/리터럴에 "곧 지원", "로드맵", "출시 예정", "차기 버전", "준비중" 등 삽입 금지.
- **Analytics 이벤트 추가 금지.** `AnalyticsService.swift` 불변. 스쿼트 시작 버튼 탭 이벤트 추가 유혹에 넘어가지 마라.
- **`docs/`, `server/`, `scripts/`, `iterations/`, `persuasion-data/`, `tasks/0-exercise-coming-soon/`, `tasks/1-coaching-samples/`, `tasks/2-tap-fallback/` 수정 금지.**
- **`README.md` 수정 금지** (Phase 0 에서 이미 처리). 이번 phase 는 코드만.
- **`project.yml` 수정 금지.** 글롭 기반이라 파일 삭제만으로 충분.
- **`TrackingView(exerciseType: "squat", ...)` 호출에서 "squat" 문자열을 상수/enum 으로 추출하지 마라.** 신규 타입 도입은 CTO 조건부 #1("내부 리팩터링은 확장 시 되살려야 할 자산") 위반 소지. 리터럴 그대로.
- **컴파일러 경고가 새로 발생하면 즉시 해결하라** (미사용 import, 미사용 state 등). AC 빌드는 경고가 있어도 성공 표기되지만, 변경 scope 이 작으므로 cleanup 포함.
- **`git mv` / 이름 변경 금지.** 이번 phase 는 1개 파일 삭제 + 1개 파일 편집. rename 없음.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0 이어야 한다.

```bash
# 1) ExercisePickerView.swift 파일 제거 + git index 에서도 제거
test ! -f Mofit/Views/Home/ExercisePickerView.swift
test -z "$(git ls-files Mofit/Views/Home/ExercisePickerView.swift)"

# 2) HomeView.swift — 삭제된 심볼이 파일 어디에도 없음
! grep -F "ExercisePickerView" Mofit/Views/Home/HomeView.swift
! grep -F "selectedExerciseName" Mofit/Views/Home/HomeView.swift
! grep -F "selectedExerciseType" Mofit/Views/Home/HomeView.swift
! grep -F "exerciseNameToType" Mofit/Views/Home/HomeView.swift
! grep -F "showExercisePicker" Mofit/Views/Home/HomeView.swift
! grep -F "exerciseSelector" Mofit/Views/Home/HomeView.swift

# 3) HomeView.swift — 신규 리터럴 존재
grep -F 'Text("스쿼트 시작")' Mofit/Views/Home/HomeView.swift
grep -F 'label: "스쿼트"' Mofit/Views/Home/HomeView.swift
grep -F 'TrackingView(exerciseType: "squat", showConfetti: $showConfetti)' Mofit/Views/Home/HomeView.swift
! grep -F 'Text("운동 시작")' Mofit/Views/Home/HomeView.swift
! grep -F 'label: "rep"' Mofit/Views/Home/HomeView.swift

# 4) 미래 약속 문구 금지 (CTO 조건부 #3)
! grep -F "곧 지원" Mofit/Views/Home/HomeView.swift
! grep -F "로드맵" Mofit/Views/Home/HomeView.swift
! grep -F "준비중" Mofit/Views/Home/HomeView.swift

# 5) CTO 조건부 #1 — 내부 분기/Counter 파일 무변경
git diff --quiet HEAD -- Mofit/ViewModels/TrackingViewModel.swift
git diff --quiet HEAD -- Mofit/Views/Tracking/TrackingView.swift
git diff --quiet HEAD -- Mofit/Services/PushUpCounter.swift
git diff --quiet HEAD -- Mofit/Services/SitUpCounter.swift
git diff --quiet HEAD -- Mofit/Services/SquatCounter.swift
git diff --quiet HEAD -- Mofit/Services/ExerciseCounter.swift

# 6) 변경 범위 엄격 — Mofit/ 하위는 HomeView.swift 수정 + ExercisePickerView.swift 삭제 + project.pbxproj 재생성만
CHANGED_MOFIT=$(git diff --name-only HEAD -- Mofit/ | sort)
EXPECTED_MOFIT=$(printf 'Mofit/Views/Home/ExercisePickerView.swift\nMofit/Views/Home/HomeView.swift\n' | sort)
test "$CHANGED_MOFIT" = "$EXPECTED_MOFIT"

# 7) xcodegen 재생성 — project.pbxproj 가 갱신되고 ExercisePickerView 참조가 제거
xcodegen generate
! grep -F "ExercisePickerView.swift" Mofit.xcodeproj/project.pbxproj

# 8) xcodebuild 빌드 성공
xcodebuild \
  -scheme Mofit \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -80

# 9) MofitTests / 신규 파일 금지 경계
test ! -d MofitTests
test ! -f Mofit/Views/Home/ExercisePicker.swift
test ! -f Mofit/Views/Home/ExercisePickerButton.swift

# 10) 외부 디렉토리 미변경 (Phase 0 docs + README 는 이미 커밋됨)
git diff --quiet HEAD -- docs/ README.md
test -z "$(git diff --name-only HEAD -- server/ scripts/ iterations/ persuasion-data/ project.yml tasks/0-exercise-coming-soon/ tasks/1-coaching-samples/ tasks/2-tap-fallback/)"

# 11) project.yml 자체 미변경
git diff --quiet HEAD -- project.yml
```

xcodebuild 출력 말미에 `** BUILD SUCCEEDED **` 가 찍혀야 한다.

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/3-squat-only-pivot/index.json` 의 phase 1 status 를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"`로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

xcodebuild 가 디스크/시뮬레이터 런타임 부재 등으로 실패하면, `xcodebuild -showsdks | grep iphonesimulator` 로 사용 가능한 SDK 를 확인하고 `-sdk` 값을 조정하라. 그래도 해결이 안 되면 `-destination 'generic/platform=iOS'` 로 전환을 시도하되, 실패 로그 전체를 `error_message` 에 기록하라.

## 주의사항

- **파일 삭제는 `git rm` 으로.** 단순 `rm` 만 사용하면 git index 에 파일이 남아 AC #1 (`git ls-files` 검사) 에 실패한다.
- **`TrackingView(exerciseType: "squat", ...)` 의 리터럴 "squat" 은 소문자.** `"Squat"`, `"SQUAT"` 금지. `TrackingViewModel` 내부 switch 가 `"squat"` 소문자 문자열을 기대한다.
- **`selectedExerciseType` 상태/계산 프로퍼티를 enum 이나 상수로 재도입하지 마라.** ADR-017 는 View 레이어 한정 제거를 명시. 내부 도메인 축소를 보이지 않게 막는 추상화는 CTO 조건부 #1 위반 소지.
- **`startButton` 에 부착하는 `.padding(.top, 32)` 는 `.padding(.horizontal)` 과 별개 모디파이어.** 두 패딩이 모두 적용되어야 원래 `exerciseSelector` 제거로 인한 세로 간격 손실을 보상한다.
- **`summaryItem` 의 `label: "스쿼트"` 변경은 비로그인/로그인 양쪽에 모두 적용.** `todayTotalReps` computed 가 내부 분기(서버 `repCounts` vs 로컬 `totalReps`) 를 이미 갖고 있으므로 라벨만 바꾸면 됨. computed 로직 수정 금지.
- **`ConfettiView`, `ConfettiParticle` 는 HomeView.swift 의 하단에 그대로 유지.** 이번 phase 는 이 두 타입과 무관.
- **`@Query profiles` 사용 여부 확인 안 해도 됨.** 본 phase 에서 사용처 재검토는 범위 밖. 불필요하다고 판단되어도 제거하지 마라.
- **다크모드 고정 유지** (ADR-007). 다크/라이트 전환 코드 추가 금지.
- **컴파일 에러가 발생하면 "ExercisePickerView 참조가 남아있는가" 를 제일 먼저 확인.** HomeView.swift 의 `.sheet` 블록, `.fullScreenCover`, body VStack, `exerciseSelector` 뷰 var 4곳에서 모두 사라져야 한다.
- **xcodegen generate 후 Mofit.xcodeproj/project.pbxproj 변경은 정상.** AC #6 의 변경 범위 grep 은 `Mofit/` 하위 Swift 소스만 본다. project.pbxproj 는 별도 AC #7 에서 검사.
- **git status --porcelain 가 clean 한 상태에서 시작.** dirty 면 error 기록 후 중단.
- **기존 테스트를 깨뜨리지 마라.** (현재 `MofitTests` target 없음. 서버 쪽 Node 테스트는 서버 미변경이라 무관.)
