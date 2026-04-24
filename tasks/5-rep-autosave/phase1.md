# Phase 1: autosave-impl

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다 (Phase 0 이 이미 커밋되어 있어야 한다).

```bash
git status --porcelain -- docs/ Mofit/ project.yml README.md
```

출력되는 파일이 있으면 working tree 가 더럽다. 진행하지 말고 `tasks/5-rep-autosave/index.json` 의 phase 1 status 를 `"error"`로 변경, `error_message` 에 `dirty working tree before phase 1` 로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/spec.md` (§2.1 트래킹 상태머신, §2.6 트래킹 autosave — Phase 0 신규. 이번 phase 설계 원전, §3.1 데이터 모델, §5 분기 테이블)
- `docs/adr.md` (ADR-009 — Phase 0 에서 업데이트됨. 이번 phase 설계 원전. ADR-013, ADR-014, ADR-017 참조)
- `docs/code-architecture.md` (§디렉토리 구조 및 ViewModel 책무)
- `docs/testing.md` (**MofitTests 타겟 신설 금지**. 이번 phase 는 build + grep 으로 AC 커버, 단위 테스트는 phase 1 에이전트의 코드 트레이스 시나리오 7개)
- `docs/user-intervention.md` (실기기 QA 절차 — Phase 0 에서 task 5 QA 항목 신규 추가)
- `tasks/5-rep-autosave/docs-diff.md` (Phase 0 docs 변경 실제 diff — runner 자동 생성)
- `iterations/6-20260424_214957/requirement.md` (iteration 원문 읽기 전용. 특히 §구현 스케치, §CTO 승인 조건부 1~5)

그리고 이전 phase 의 작업물 + 기존 코드를 반드시 확인하라:

- `Mofit/ViewModels/TrackingViewModel.swift` — **수정 대상**. 기존 구조(참조용):
  - L8~13 `enum TrackingState` — **불변**
  - L15~32 `enum DiagnosticHint` + computed props — **불변**
  - L34~48 `@Published` 프로퍼티 + private services + `evaluator` — **프로퍼티 추가는 이 영역에**
  - L50~53 `exerciseType`, 3종 Counter — **불변**
  - L55~62 `countdownTimer`, `elapsedTimer`, `palmDetectionStartTime`, `sessionStartTime`, `hasStartedElapsedTimer`, `cancellables`, `viewSize` — **불변**. 신규 stored property 4개는 이 블록 **뒤** 에 추가.
  - L64~87 `init` — **불변**
  - L89~106 `setupBindings()` — **수정 대상** (3개 Counter sink 에 persistRepSnapshot 호출 추가)
  - L108~110 `captureSession` computed — **불변**
  - L112~133 `startSession()` — **수정 대상 (시그니처 변경 + reset 로직 확장)**
  - L135~180 `stopSession(modelContext:isLoggedIn:)` — **수정 대상 (!isLoggedIn 분기 교체)**
  - L182~200 `processFrame(_:)` — **불변** (ADR-018 호출 순서 5단계 고정 주석 유지)
  - L202~219 `handlePalmDetection`, L221~232 `handleScreenTap`, L234~237 `triggerHapticFeedback`, L239~248 `triggerSetAction` — **불변**
  - L250~277 `startCountdown()` — **수정 대상** (첫 진입 시 insert)
  - L279~284 `startTracking()` — **불변**
  - L286~290 `processJointsForExercise` — **불변**
  - L292~296 `resetCounter` — **불변**
  - L298~308 `completeSet()` — **수정 대상** (snapshot 확정 save 추가)
  - L310~317 `startElapsedTimer` — **불변**
  - L319~329 `updateJointPoints` — **불변**
  - L332~341 `extension TrackingViewModel { enum Diagnostic }` — **불변**
  - L343~416 `fileprivate struct DiagnosticHintEvaluator` — **불변**
- `Mofit/Views/Tracking/TrackingView.swift` — **수정 대상**. `onAppear` 의 `viewModel.startSession()` 호출 1곳만 시그니처 변경.
- `Mofit/Views/Records/RecordsView.swift` — **수정 대상**. `filteredSessions` 의 filter predicate 에 `$0.totalReps > 0` 한 조건 추가.
- `Mofit/Models/WorkoutSession.swift` — **스키마 불변. 수정 금지.**
- `Mofit/Services/SquatCounter.swift`, `Mofit/Services/PushUpCounter.swift`, `Mofit/Services/SitUpCounter.swift`, `Mofit/Services/ExerciseCounter.swift`, `Mofit/Services/HandDetectionService.swift`, `Mofit/Services/PoseDetectionService.swift` — **수정 금지**.
- `Mofit/Services/APIService.swift`, `Mofit/Services/AuthManager.swift` — **수정 금지** (로그인 경로 불변).
- `Mofit/Camera/*`, `Mofit/Views/Home/*`, `Mofit/Views/Onboarding/*`, `Mofit/Views/Coaching/*`, `Mofit/Views/Profile/*` — **수정 금지**.
- `project.yml` — **수정 금지**. 기존 파일만 수정하므로 xcodegen 재생성 시 변화 없음.

**목표**: TVM 1 파일 확장 + TrackingView 1 줄 수정 + RecordsView 1 줄 수정. 신규 `.swift` 파일 생성 금지. `MofitTests/` 디렉토리 생성 금지. 스키마 변경 금지.

## 작업 내용

### 대상 파일 (정확히 3개 + xcodegen 재생성)

1. **확장**: `Mofit/ViewModels/TrackingViewModel.swift`
2. **수정 (1줄)**: `Mofit/Views/Tracking/TrackingView.swift`
3. **수정 (1조건)**: `Mofit/Views/Records/RecordsView.swift`
4. **재생성**: `Mofit.xcodeproj/project.pbxproj` (xcodegen 자동)

### 목적

iter 6 persona(`home-workout-newbie-20s`, `risk_preference: conservative`) 의 "트래킹 중 rep 이 날아감 → 신뢰도 붕괴 → 즉시 이탈" 경로를 막는다. 해결책은 "이어하기 UI" 가 **아니라** "이미 persist 된 상태로 기록 탭에 자연스럽게 노출" — 2rep 한 상태에서 크래시가 나도 기록 탭에 2rep 세션이 남는다.

### 구현 요구사항

#### 1) `Mofit/ViewModels/TrackingViewModel.swift`

##### 1-a) 신규 stored property 4개 추가

기존 `private var evaluator = DiagnosticHintEvaluator()` 라인(대략 L48) 다음 줄에 아래 4개를 **연속해서** 추가한다:

```swift
    private var currentSession: WorkoutSession?
    private var storedModelContext: ModelContext?
    private var storedIsLoggedIn: Bool = false
    private var lastSavedReps: Int = 0
```

- `WorkoutSession` / `ModelContext` 타입은 이미 파일 상단 `import SwiftData` 로 쓸 수 있다.
- **프로퍼티 추가 위치 고정**: `evaluator` 바로 뒤, `exerciseType` / `squatCounter` 선언 **앞**. 파일 상단 stored property 블록 안에 시각적으로 그룹으로 묶이도록 한다.

##### 1-b) `startSession()` 시그니처 변경

**기존 (L112~133)**:

```swift
    func startSession() {
        state = .idle
        currentSet = 1
        currentReps = 0
        elapsedTime = 0
        jointPoints = []
        repCounts = []
        palmDetectionStartTime = nil
        sessionStartTime = nil
        hasStartedElapsedTimer = false
        resetCounter()
        diagnosticHint = nil
        evaluator.reset()

        cameraManager.onFrameCaptured = { [weak self] sampleBuffer in
            Task { @MainActor [weak self] in
                self?.processFrame(sampleBuffer)
            }
        }

        cameraManager.startSession()
    }
```

**신규**:

```swift
    func startSession(modelContext: ModelContext, isLoggedIn: Bool) {
        state = .idle
        currentSet = 1
        currentReps = 0
        elapsedTime = 0
        jointPoints = []
        repCounts = []
        palmDetectionStartTime = nil
        sessionStartTime = nil
        hasStartedElapsedTimer = false
        resetCounter()
        diagnosticHint = nil
        evaluator.reset()
        storedModelContext = modelContext
        storedIsLoggedIn = isLoggedIn
        currentSession = nil
        lastSavedReps = 0

        cameraManager.onFrameCaptured = { [weak self] sampleBuffer in
            Task { @MainActor [weak self] in
                self?.processFrame(sampleBuffer)
            }
        }

        cameraManager.startSession()
    }
```

- 두 인자 모두 **필수** (optional 기본값 금지).
- 4줄 추가(`storedModelContext` / `storedIsLoggedIn` / `currentSession = nil` / `lastSavedReps = 0`) 위치는 `evaluator.reset()` 뒤, `cameraManager.onFrameCaptured` 블록 **앞**.

##### 1-c) `setupBindings()` — 3개 sink 에 persistRepSnapshot 호출 추가

**기존 (L89~106)** 의 3개 sink 각각에서 `self?.currentReps = reps` 다음 줄에 `self?.persistRepSnapshot()` 한 줄 추가. 예:

```swift
            counter.$currentReps
                .receive(on: DispatchQueue.main)
                .sink { [weak self] reps in
                    self?.currentReps = reps
                    self?.persistRepSnapshot()
                }
                .store(in: &cancellables)
```

- squatCounter / pushUpCounter / sitUpCounter **3개 sink 전부** 에 동일 1줄 추가.
- closure 의 signature 가 단일 표현식에서 body 블록으로 바뀌므로 `{` `}` 스타일 주의.

##### 1-d) `startCountdown()` — 첫 진입 시 insert

**기존 (L250~277)** 의 `if !hasStartedElapsedTimer` 블록(`hasStartedElapsedTimer = true; sessionStartTime = Date(); startElapsedTimer()`) 을 보존하면서, **이 블록 안** 에 `!storedIsLoggedIn && currentSession == nil` 가드로 insert 로직을 추가한다.

**신규 블록 내부**:

```swift
        if !hasStartedElapsedTimer {
            hasStartedElapsedTimer = true
            sessionStartTime = Date()
            startElapsedTimer()

            if !storedIsLoggedIn && currentSession == nil, let ctx = storedModelContext {
                let startedAt = sessionStartTime ?? Date()
                let session = WorkoutSession(
                    exerciseType: exerciseType,
                    startedAt: startedAt,
                    endedAt: startedAt,
                    totalDuration: 0,
                    repCounts: []
                )
                ctx.insert(session)
                do {
                    try ctx.save()
                } catch {
                    print("autosave failed: \(error)")
                }
                currentSession = session
            }
        }
```

- `sessionStartTime ?? Date()` — 방어적. 방금 할당했으니 nil 은 아니지만 force-unwrap 회피.
- `do { try ctx.save() } catch { print(...) }` 형태로 에러를 **print 만**. `saveError` / alert 건드리지 마라.
- `currentSession = session` 을 save 이후에 세팅해 (save 실패해도 session 참조는 유지 — 다음 snapshot 시도에 다시 save 기회).

##### 1-e) 신규 private 메서드 `persistRepSnapshot()`

`updateJointPoints(_:)` 의 `}` (L329) **직후**, `extension TrackingViewModel { enum Diagnostic ... }` **앞** 에 아래 메서드를 추가한다. 즉 `TrackingViewModel` 클래스 내부 **마지막** 메서드.

```swift
    private func persistRepSnapshot() {
        guard !storedIsLoggedIn,
              let ctx = storedModelContext,
              let session = currentSession else { return }
        guard currentReps != lastSavedReps else { return }

        let snapshot = repCounts + (currentReps > 0 ? [currentReps] : [])
        session.repCounts = snapshot
        session.endedAt = Date()
        session.totalDuration = elapsedTime
        do {
            try ctx.save()
        } catch {
            print("autosave failed: \(error)")
        }
        lastSavedReps = currentReps
    }
```

- 순서 고정: guard 2개 → snapshot 계산 → session 필드 3개 update → save → `lastSavedReps = currentReps`.
- `lastSavedReps = currentReps` 는 save 실패 여부와 무관하게 호출(다음 방출에서 재시도 로직은 sink 가 다음 rep 시 다시 태운다. 영속성은 eventual).

##### 1-f) `completeSet()` — snapshot 확정 save 추가

**기존 (L298~308)**:

```swift
    private func completeSet() {
        if currentReps > 0 {
            repCounts.append(currentReps)
        }
        state = .setComplete
        currentSet += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startCountdown()
        }
    }
```

**신규**:

```swift
    private func completeSet() {
        if currentReps > 0 {
            repCounts.append(currentReps)
        }
        state = .setComplete
        currentSet += 1

        if !storedIsLoggedIn, let ctx = storedModelContext, let session = currentSession {
            session.repCounts = repCounts
            session.endedAt = Date()
            session.totalDuration = elapsedTime
            do {
                try ctx.save()
            } catch {
                print("autosave failed: \(error)")
            }
            lastSavedReps = currentReps
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startCountdown()
        }
    }
```

- `repCounts.append` 이후이므로 snapshot 은 `repCounts` 그대로 (tail 없음, 중복 방지).
- `lastSavedReps = currentReps` 로 동기화해 **이후 `resetCounter()` 에서 0 방출 시** sink 의 `currentReps != lastSavedReps` 가드가 `0 != currentReps(현재)` 구도로 오작동하지 않게 함. (실제 `resetCounter` 는 `startTracking` 이 호출하는데 그보다 `completeSet → .setComplete → 1s asyncAfter → startCountdown → (차기 세트 첫 번째면 skip 또는) startTracking → resetCounter → currentReps=0 방출 → sink → persistRepSnapshot → 0 != lastSavedReps=currentReps_before_reset 이면 save 실행`. 이 추가 save 는 `repCounts + []` 로 동일 값을 다시 쓴 것. 무해.)

##### 1-g) `stopSession(modelContext:isLoggedIn:)` — !isLoggedIn 분기 교체

**기존 (L135~180)** 의 `else` 브랜치(`!isLoggedIn` 즉 `else`):

```swift
        } else {
            let session = WorkoutSession(
                exerciseType: exerciseType,
                startedAt: startedAt,
                endedAt: endedAt,
                totalDuration: elapsedTime,
                repCounts: repCounts
            )
            modelContext.insert(session)
        }
```

를 아래로 교체:

```swift
        } else {
            if let session = currentSession {
                session.repCounts = repCounts
                session.endedAt = endedAt
                session.totalDuration = elapsedTime
                do {
                    try modelContext.save()
                } catch {
                    print("autosave failed: \(error)")
                }
            }
        }
        currentSession = nil
        lastSavedReps = 0
        storedModelContext = nil
```

- **`modelContext.insert(session)` 호출은 절대 남기지 마라**. AC 8 grep 이 `modelContext.insert` 호출 수를 정확히 1 로 검증(startCountdown 의 1곳만 허용).
- 로그인(`if isLoggedIn`) 분기(서버 API POST) 는 **완전 불변**.
- `currentSession = nil` / `lastSavedReps = 0` / `storedModelContext = nil` 은 `else` 블록 밖, `if/else` 공통 종료 라인으로 둔다(로그인 유저는 처음부터 `currentSession` / `storedModelContext` 가 nil 이라 무해).
- `storedIsLoggedIn` 은 다음 `startSession` 에서 덮어쓰므로 여기서 reset 할 필요 없음.

##### 1-h) Counter `currentReps = 0` 방출 확인 (코드 수정 금지, 트레이스만)

`SquatCounter.swift` / `PushUpCounter.swift` / `SitUpCounter.swift` 모두 `reset()` 내부에서 `currentReps = 0` 을 호출하는지 **코드 읽기로만 확인**. 확인 결과를 `tasks/5-rep-autosave/phase1-output.json` 의 stdout(또는 에이전트 로그) 에 한 줄로 남긴다. 수정은 금지.

#### 2) `Mofit/Views/Tracking/TrackingView.swift`

**수정 대상 단 1줄**. `onAppear` 의:

```swift
                viewModel.startSession()
```

를:

```swift
                viewModel.startSession(modelContext: modelContext, isLoggedIn: authManager.isLoggedIn)
```

로 교체. 다른 라인 일체 수정 금지. `modelContext` 와 `authManager` 는 이미 이 파일 상단에서 각각 `@Environment`, `@EnvironmentObject` 로 주입되어 있으므로 그대로 참조 가능.

#### 3) `Mofit/Views/Records/RecordsView.swift`

**수정 대상 단 1조건**. `filteredSessions` computed(L16~19):

```swift
    private var filteredSessions: [WorkoutSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: selectedDate) }
    }
```

를:

```swift
    private var filteredSessions: [WorkoutSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: selectedDate) && $0.totalReps > 0 }
    }
```

로 교체. 다른 라인 일체 수정 금지.

- `filteredServerSessions` 은 **수정 금지**. 로그인 유저 서버 경로는 이번 task 에서 0rep 세션을 만들지 않으므로 필터 불필요(ADR-013).

#### 4) xcodegen generate

```bash
xcodegen generate
```

- `project.yml` 글롭 기반이라 파일 수정만으로 pbxproj 재생성 시 자동 반영. 파일 추가/삭제 없으므로 pbxproj 변경은 최소.

### 구현 후 코드 트레이스 검증 (MofitTests 대체)

아래 7개 시나리오를 **에이전트가 직접 코드 흐름을 따라가며 수학적으로 검증**하라(단위 테스트 파일 생성 금지). 각 시나리오의 예상 결과와 실제 동작이 일치해야 한다. 불일치 시 구현 수정.

각 시나리오 시작 시 `viewModel.startSession(modelContext: ctx, isLoggedIn: X)` 에서 X 는 표기된 대로.

1. **정상 멀티세트 (비로그인)** — `X=false`. countdown 첫 진입 → insert(session, repCounts=[]). rep 1..5 방출 → 각 rep 마다 sink → persistRepSnapshot 5회 호출 → `session.repCounts` 는 `[] + [1]` → `[] + [2]` → ... → `[] + [5]`. `completeSet()` 호출 → `self.repCounts = [5]` append → completeSet 내부 save 에서 `session.repCounts = [5]`. 1초 후 `startCountdown` → 이미 `hasStartedElapsedTimer=true` 라 재 insert 안 함 → `startTracking` → `resetCounter` → Counter.$currentReps=0 방출 → sink → persistRepSnapshot. 이때 `currentReps=0 != lastSavedReps=5` 라 save 진입, snapshot=`[5] + [] = [5]`. 무해한 중복 save. 이어서 rep 1..3 → sink 3회 → `session.repCounts` 는 `[5]+[1]` → `[5]+[2]` → `[5]+[3]`. stopSession 호출 → `repCounts.append(3)` → `self.repCounts=[5,3]` → else 분기에서 `session.repCounts=[5,3]`, `endedAt`, `totalDuration` 반영, save. 최종 `session.repCounts == [5, 3]`, `currentSession == nil`.
2. **크래시 복구 (비로그인)** — `X=false`. countdown 첫 진입 insert. rep 1, 2 방출 → sink 2회 → `session.repCounts = [1]` → `[2]`. **stopSession 미호출** (앱 kill). 앱 재실행 후 `@Query sessions` fetch → 위 session 이 로드. `RecordsView` 의 필터 `$0.totalReps > 0` 이 `2 > 0` 이므로 true → 카드 노출. 이어하기 버튼 / 시트 없음 (scope 외). **기대**: 기록 탭 오늘 날짜에 "1세트 · 2회 · (elapsed)" 카드.
3. **0rep 세션 필터** — `X=false`. countdown 첫 진입 insert(`repCounts=[]`). rep 한 번도 안 올라옴(`currentReps=0`). stopSession → `currentReps > 0` 가드로 append 스킵 → `self.repCounts=[]` → else 분기에서 `session.repCounts=[]`, save. `session.totalReps == 0`. `RecordsView` 필터로 카드 숨김. **기대**: 기록 탭 오늘 날짜에 세션 카드 없음(다른 세션 없다면 "이 날은 운동 기록이 없어요" 표시).
4. **로그인 유저 경로 불변** — `X=true`. countdown 첫 진입 → `!storedIsLoggedIn` 가드로 insert **스킵**. `currentSession == nil` 유지. rep 1..3 방출 → sink 3회 → persistRepSnapshot 호출되지만 `!storedIsLoggedIn` guard 로 **즉시 return**. `ctx.save` / `session.repCounts` 터치 안 됨. stopSession → `if isLoggedIn` 분기 → `ServerSession` 생성 + APIService.shared.createSession 호출. else 분기 진입 안 함. `currentSession = nil` (원래 nil), `storedModelContext = nil`. **기대**: SwiftData 에 row 추가 없음(grep 대신 코드 트레이스로 증명), 서버 POST 호출 1회.
5. **no-op 가드** — `X=false`. Counter 가 `resetCounter()` 후 `currentReps=0` 재방출. sink → persistRepSnapshot → `currentReps != lastSavedReps` 가드: 직전 lastSavedReps=0 (초기값) 이면 `0 != 0` false → return. save 스킵. **기대**: 불필요한 save 발생 안 함. (단 시나리오 1 에서 본 "completeSet 후 resetCounter 로 0 방출 시 lastSavedReps=5 였다가 `0 != 5` true → save 진입 후 `lastSavedReps=0` 세팅" 은 1회성 중복 save 로 허용.)
6. **tail 중복 방지** — `X=false`. completeSet 내부 direct save: `session.repCounts = repCounts` (append 직후라 `[10, 8]`). 이후 `startTracking` → `resetCounter` → Counter 0 방출 → sink → persistRepSnapshot → `currentReps=0` 이므로 snapshot = `[10, 8] + [] = [10, 8]`. tail 재삽입 없음. 다음 rep=1 → snapshot = `[10, 8] + [1] = [10, 8, 1]`. 정상.
7. **completeSet 직후 즉시 stopSession** — `X=false`. rep 1..5 → completeSet → `self.repCounts=[5]`, completeSet 내부 save 에서 `session.repCounts=[5]`. `setComplete` 상태 1초 대기 중 사용자가 stop 버튼(혹은 closeButton) → stopSession 호출. stopSession 내부: `currentReps` 는 completeSet 에서 이미 로직 흐름상 0 으로 리셋되지 않았음에 주의 — 현재 코드는 completeSet 에서 currentReps 를 명시적으로 0 으로 안 내린다(resetCounter 는 startTracking 에서 호출). 즉 `currentReps` 는 여전히 5 일 수 있음 → stopSession 의 `if currentReps > 0 { repCounts.append(currentReps) }` 라인에서 `repCounts.append(5)` **중복 append** 발생 → `self.repCounts=[5,5]`. **이 버그는 기존 코드에도 존재**(신규 변경이 아님). 그러나 현재 흐름에서 `setComplete` 상태 1초 동안 stop 버튼이 어떻게 작동하는지 확인 필요. TrackingView 의 stopButton 은 state 무관 항상 활성. 사용자가 1초 안에 누를 가능성 낮지만 가능. **결정**: 이 버그는 이번 phase scope 외(기존 버그 유지). stopSession 의 `currentReps > 0` 중복 append 이슈는 별건 티켓. AC 는 "stopSession 직후 session.repCounts 가 self.repCounts 와 일치" 까지만 검증. 기존 버그가 `[5,5]` 를 만들면 session.repCounts 도 `[5,5]` 로 일치한다. **기대**: `session.repCounts == self.repCounts`, save 호출 성공.

검증 실패 시 구현 재검토. 특히 1-c(sink 내 호출 추가), 1-d(startCountdown 가드), 1-e(persistRepSnapshot 가드 순서), 1-f(completeSet 내 save), 1-g(stopSession else 교체) 위치를 재확인.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0 이어야 한다.

```bash
# 1) TVM — 신규 stored property 4개
grep -F 'private var currentSession: WorkoutSession?' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'private var storedModelContext: ModelContext?' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'private var storedIsLoggedIn: Bool = false' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'private var lastSavedReps: Int = 0' Mofit/ViewModels/TrackingViewModel.swift

# 2) TVM — startSession 시그니처 변경
grep -F 'func startSession(modelContext: ModelContext, isLoggedIn: Bool)' Mofit/ViewModels/TrackingViewModel.swift
! grep -E '^\s+func startSession\(\)' Mofit/ViewModels/TrackingViewModel.swift

# 3) TVM — persistRepSnapshot 메서드 + snapshot 계산 라인
grep -F 'private func persistRepSnapshot()' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'let snapshot = repCounts + (currentReps > 0 ? [currentReps] : [])' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'guard currentReps != lastSavedReps else { return }' Mofit/ViewModels/TrackingViewModel.swift

# 4) TVM — setupBindings 의 3개 sink 모두 persistRepSnapshot 호출 추가
test "$(grep -cF 'self?.persistRepSnapshot()' Mofit/ViewModels/TrackingViewModel.swift)" -ge 3

# 5) TVM — startCountdown 안에서 insert + save (1곳)
test "$(grep -cF 'ctx.insert(session)' Mofit/ViewModels/TrackingViewModel.swift)" -eq 1
grep -F '!storedIsLoggedIn && currentSession == nil' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'sessionStartTime ?? Date()' Mofit/ViewModels/TrackingViewModel.swift

# 6) TVM — modelContext.insert 는 더 이상 존재하지 않는다(교체됨. ctx.insert 로만).
! grep -F 'modelContext.insert(session)' Mofit/ViewModels/TrackingViewModel.swift

# 7) TVM — stopSession 의 else 분기가 currentSession 을 쓰도록 교체됨
grep -F 'if let session = currentSession {' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'currentSession = nil' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'lastSavedReps = 0' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'storedModelContext = nil' Mofit/ViewModels/TrackingViewModel.swift
# WorkoutSession 생성은 startCountdown 안 1곳만 허용
test "$(grep -cF 'WorkoutSession(' Mofit/ViewModels/TrackingViewModel.swift)" -eq 1

# 8) TVM — save 호출 최소 3회 이상(insert + persistRepSnapshot + completeSet + stopSession)
test "$(grep -cF 'try ctx.save()' Mofit/ViewModels/TrackingViewModel.swift)" -ge 2
test "$(grep -cF 'try modelContext.save()' Mofit/ViewModels/TrackingViewModel.swift)" -ge 1
test "$(grep -cF 'print("autosave failed:' Mofit/ViewModels/TrackingViewModel.swift)" -ge 3

# 9) TVM — saveError 는 로그인 유저 서버 실패 경로만 건드림 (autosave 경로는 print 만)
# autosave 영역에서 saveError 를 세팅하면 tracking 중 alert 뜸 — 금지
test "$(grep -cF 'saveError = ' Mofit/ViewModels/TrackingViewModel.swift)" -eq 1

# 10) TVM — DiagnosticHint 관련 기존 로직 불변
grep -F 'enum DiagnosticHint' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'struct DiagnosticHintEvaluator' Mofit/ViewModels/TrackingViewModel.swift
grep -F 'poseDetectionService.detectPoseDetailed(' Mofit/ViewModels/TrackingViewModel.swift

# 11) TrackingView — onAppear 의 startSession 호출 시그니처 교체
grep -F 'viewModel.startSession(modelContext: modelContext, isLoggedIn: authManager.isLoggedIn)' Mofit/Views/Tracking/TrackingView.swift
! grep -E 'viewModel\.startSession\(\s*\)' Mofit/Views/Tracking/TrackingView.swift

# 12) RecordsView — filteredSessions 에 totalReps>0 필터 추가
grep -F '$0.totalReps > 0' Mofit/Views/Records/RecordsView.swift
grep -F 'calendar.isDate($0.startedAt, inSameDayAs: selectedDate) && $0.totalReps > 0' Mofit/Views/Records/RecordsView.swift
# filteredServerSessions 은 수정 금지 → totalReps 필터 없음
! grep -F 'ServerSession.*totalReps' Mofit/Views/Records/RecordsView.swift

# 13) WorkoutSession 스키마 불변
git diff --quiet HEAD -- Mofit/Models/WorkoutSession.swift

# 14) 로그인/Counter/카메라 경로 무변경
git diff --quiet HEAD -- Mofit/Services/APIService.swift
git diff --quiet HEAD -- Mofit/Services/AuthManager.swift
git diff --quiet HEAD -- Mofit/Services/SquatCounter.swift
git diff --quiet HEAD -- Mofit/Services/PushUpCounter.swift
git diff --quiet HEAD -- Mofit/Services/SitUpCounter.swift
git diff --quiet HEAD -- Mofit/Services/ExerciseCounter.swift
git diff --quiet HEAD -- Mofit/Services/HandDetectionService.swift
git diff --quiet HEAD -- Mofit/Services/PoseDetectionService.swift
git diff --quiet HEAD -- Mofit/Camera/CameraManager.swift
git diff --quiet HEAD -- Mofit/Camera/CameraPreviewView.swift
git diff --quiet HEAD -- Mofit/Views/Home/HomeView.swift

# 15) 변경 범위 — Mofit/ 하위 정확히 3개 파일
CHANGED_MOFIT=$(git diff --name-only HEAD -- Mofit/ | sort)
EXPECTED_MOFIT=$(printf 'Mofit/ViewModels/TrackingViewModel.swift\nMofit/Views/Records/RecordsView.swift\nMofit/Views/Tracking/TrackingView.swift\n' | sort)
test "$CHANGED_MOFIT" = "$EXPECTED_MOFIT"

# 16) 신규 파일 금지
test ! -d MofitTests
test ! -f Mofit/ViewModels/AutosavePolicy.swift
test ! -f Mofit/Models/WorkoutSessionDraft.swift

# 17) 미래 약속 문구 금지
! grep -F '곧 지원' Mofit/ViewModels/TrackingViewModel.swift
! grep -F '로드맵' Mofit/ViewModels/TrackingViewModel.swift
! grep -F '이어하기' Mofit/ViewModels/TrackingViewModel.swift
! grep -F '이어하기' Mofit/Views/Records/RecordsView.swift
! grep -F 'isInProgress' Mofit/ViewModels/TrackingViewModel.swift
! grep -F 'isInProgress' Mofit/Models/WorkoutSession.swift

# 18) Analytics 이벤트 추가 금지
! grep -rF 'workout_interrupted' Mofit/
! grep -F 'Mixpanel' Mofit/ViewModels/TrackingViewModel.swift

# 19) xcodegen 재생성 + xcodebuild 빌드 성공
xcodegen generate
xcodebuild \
  -scheme Mofit \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -80

# 20) 외부 디렉토리 미변경
git diff --quiet HEAD -- docs/ README.md project.yml server/ scripts/ iterations/ persuasion-data/ tasks/0-exercise-coming-soon/ tasks/1-coaching-samples/ tasks/2-tap-fallback/ tasks/3-squat-only-pivot/ tasks/4-diagnostic-hint/
```

xcodebuild 출력 말미에 `** BUILD SUCCEEDED **` 가 찍혀야 한다.

AC 18 은 `grep -rF` 를 쓴다. macOS BSD grep 도 `-r` 를 지원한다.

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `tasks/5-rep-autosave/index.json` 의 phase 1 status 를 `"completed"` 로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"` 로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

xcodebuild 가 디스크/시뮬레이터 런타임 부재 등으로 실패하면, `xcodebuild -showsdks | grep iphonesimulator` 로 SDK 확인 후 `-sdk` 값을 조정하라. 그래도 해결이 안 되면 `-destination 'generic/platform=iOS'` 로 전환 시도. 실패 시 로그 전체를 `error_message` 에 기록.

## 주의사항

- **"세션" 정의 고정**: 세션 = `TrackingView` lifecycle = `startSession(...)` 호출 ~ `stopSession(...)` 종료. 1 세션당 `WorkoutSession` **1 row**. 세트 경계에서 추가 insert 금지. `currentSession == nil` / `hasStartedElapsedTimer == false` **둘 다** 체크해야 중복 insert 방지 (가드 c = a AND b, 이전 논의).
- **persist 실패 정책**: 모든 save 실패는 `print("autosave failed: \(error)")` **만**. `saveError` / alert 건드리지 마라. `saveError` 는 로그인 유저의 서버 저장 실패 경로 전용(TrackingView.swift L63~72 alert 트리거).
- **로그인 유저 경로 불변**: `storedIsLoggedIn == true` 인 모든 autosave 경로는 **즉시 return**. `ctx.insert` / `ctx.save` / `session.repCounts` / `session.endedAt` 터치 금지. stopSession 의 `if isLoggedIn` 서버 POST 블록은 완전 불변.
- **모델 스키마 변경 금지**: `Mofit/Models/WorkoutSession.swift` 수정 시 AC 13 실패. `isInProgress: Bool` / `isRecovered: Bool` / `wasInterrupted: Bool` 같은 플래그 **절대 추가 금지** (CTO 조건 5, iteration §명시적으로 하지 않는 것).
- **이어하기 UI 금지**: HomeView 복구 시트, "이어하기" 버튼, `workout_interrupted_*` analytics 이벤트, UserDefaults/별도 임시 저장 경로 **전부 금지** (iteration §Phase 1 에서 명시적으로 하지 않는 것).
- **RecordsView `filteredServerSessions` 수정 금지**: 로그인 유저 서버 경로는 이번 task 에서 0rep 세션을 만들지 않음. 필터 중복 추가는 ADR-013 일관성 훼손.
- **`persistRepSnapshot` 의 가드 순서 고정**: (1) `!storedIsLoggedIn` + `storedModelContext != nil` + `currentSession != nil`, (2) `currentReps != lastSavedReps`. 순서 바꾸면 로그인 유저에서도 `lastSavedReps` 비교가 돌아가 성능 미세 저하(영향 없지만 읽기 힘들어짐).
- **`sessionStartTime` force-unwrap 금지**: `startCountdown` 의 insert 블록에서 `sessionStartTime!` 사용 금지. `?? Date()` 방어.
- **`ModelContext` 보관 수명**: stopSession 에서 `storedModelContext = nil` 로 해제. TVM deinit 을 굳이 추가하지 마라 (class 해제 시 자동 해제).
- **tail 중복 방지는 `completeSet` + `lastSavedReps` 동기화로**: completeSet 내부 save 후 `lastSavedReps = currentReps` 세팅. 이후 sink 에서 0 방출 시 `0 != currentReps` 기준으로 1회 중복 save(무해) 발생 허용.
- **ADR-013 / ADR-014 / ADR-017 / ADR-018 불변**: 로그인/비로그인 분기, 네트워크 실패 정책, 스쿼트 전용 포지셔닝, 진단 힌트 로직 전부 수정 금지.
- **기존 테스트를 깨뜨리지 마라**: (현재 `MofitTests` 없음. 서버 쪽 Node 테스트는 서버 미변경이라 무관.)
- **컴파일러 경고 발생 시 즉시 해결**: 미사용 import, 미사용 변수 등. AC 빌드는 경고 있어도 성공 표기되지만, 이번 phase 변경 scope 안에서 cleanup 포함.
- **git status 클린 상태 시작**: dirty 면 error 기록 후 중단.
- **실기기 QA 는 AC 범위 밖**: `docs/user-intervention.md` Phase 0 에서 추가한 §트래킹 autosave 실기기 QA 절차대로 사람이 merge 전 수행. phase 1 완료 조건은 xcodebuild 성공 + grep 가드 통과.
