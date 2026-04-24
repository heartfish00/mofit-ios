# Phase 1: generator-impl

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다 (Phase 0 이 이미 커밋되어 있어야 한다).

```bash
git status --porcelain -- docs/ Mofit/ MofitTests/ project.yml README.md
```

출력되는 파일이 있으면 working tree 가 더럽다. 진행하지 말고 `tasks/6-coaching-generator/index.json` 의 phase 1 status 를 `"error"`로 변경, `error_message` 에 `dirty working tree before phase 1` 로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/spec.md` (§1 탭 구성, §2.7 비로그인 코칭 샘플 생성 — Phase 0 신규. 이번 phase 설계 원전. §3.1 데이터 모델, §5 분기 테이블)
- `docs/adr.md` (ADR-006 — Phase 0 에서 업데이트됨. 이번 phase 설계 원전. ADR-012, ADR-013, ADR-015, ADR-017 참조)
- `docs/code-architecture.md` (디렉토리 구조, 특히 `Views/Coaching/` 블록 — Phase 0 에서 `CoachingSamples.swift` 라인 추가됨)
- `docs/testing.md` (파일 끝 "XCTest 타겟" 섹션 — Phase 0 신규. MofitTests 타겟 신설 허용 근거. 2 케이스 한정.)
- `tasks/6-coaching-generator/docs-diff.md` (Phase 0 docs 변경 실제 diff — runner 자동 생성)
- `iterations/7-20260424_224239/requirement.md` (iteration 원문 읽기 전용. 특히 §구현 스케치 1~5, §CTO 승인 조건부 조건 1~4)

그리고 이전 phase 의 작업물 + 기존 코드를 반드시 확인하라:

- `Mofit/Views/Coaching/CoachingSamples.swift` — **전면 교체**. 현재 구조(참조용, 교체 전):
  - L3~7 `struct CoachingSample: Identifiable { id, type, content }` — **보존**
  - L9~20 `enum CoachingSamples { static let all: [CoachingSample] = [ ...2개 하드코딩 ... ] }` — **제거**
- `Mofit/Views/Coaching/CoachingView.swift` — **부분 수정**. 현재 구조(참조용):
  - L1~17 import / properties — **불변**. `@Query private var profiles: [UserProfile]` (L8), `@Query private var sessions: [WorkoutSession]` (L9) 이미 존재 → 새 `@Query` 선언 금지.
  - L19~21 `private var profile: UserProfile? { profiles.first }` — **불변**. 재사용.
  - L131~191 `notLoggedInContent` — **수정 대상**. L149 `ForEach(CoachingSamples.all)` 교체.
  - L193~214 `sampleFeedbackCard(sample:)` — **불변**. `CoachingSample` 타입 시그니처 그대로 유지되므로 호환.
  - 나머지 로그인 유저 경로 (L116~129 `loggedInContent`, L294~318 `requestFeedback`, L320~415 feedbackList 관련) — **전부 불변**.
- `Mofit/Models/UserProfile.swift` — **수정 금지**. 필드 참조용: `gender, height, weight, bodyType, goal, coachStyle`. `onboardingCompleted` 필드는 **존재하지 않음** — `@AppStorage("onboardingCompleted")` 키로 관리됨(`MofitApp.swift`, `OnboardingView.swift`, `ProfileEditView.swift` 참조). generator / CoachingView 에 이 키를 주입하지 마라.
- `Mofit/Models/WorkoutSession.swift` — **수정 금지**. 필드: `id, exerciseType, startedAt, endedAt, totalDuration, repCounts: [Int]`. computed `totalSets`, `totalReps` 제공.
- `Mofit/ViewModels/CoachingViewModel.swift` — **수정 금지**. 로그인 유저 API 호출 경로 전용. generator 와 무관.
- `Mofit/Services/*`, `Mofit/Camera/*`, `Mofit/Views/Home/*`, `Mofit/Views/Onboarding/*`, `Mofit/Views/Profile/*`, `Mofit/Views/Records/*`, `Mofit/Views/Tracking/*`, `Mofit/App/*` — **수정 금지**.
- `project.yml` — **MofitTests target 블록 1개만 추가**. 기존 `Mofit` target 설정 수정 금지. `schemes:` 블록에 test action 1개 추가만.
- `Mofit.xcodeproj/project.pbxproj` — xcodegen 이 재생성. 직접 편집 금지.

**목표**: `CoachingSamples.swift` 교체(삭제+신규 추가) + `CoachingView.swift` 비로그인 분기 부분 수정 + `project.yml` MofitTests target 추가 + `MofitTests/CoachingSampleGeneratorTests.swift` 1 파일 생성 + `xcodegen generate` + build + test.

## 작업 내용

### 대상 파일 (정확히 4개 + xcodegen 재생성)

1. **전면 교체**: `Mofit/Views/Coaching/CoachingSamples.swift`
2. **부분 수정**: `Mofit/Views/Coaching/CoachingView.swift`
3. **부분 수정**: `project.yml` (MofitTests target 추가 + test scheme 추가)
4. **신규 생성**: `MofitTests/CoachingSampleGeneratorTests.swift`
5. **재생성**: `Mofit.xcodeproj/project.pbxproj` (xcodegen 자동)

### 목적

iter 7 persona(`home-workout-newbie-20s`, `trust_with_salesman: 40`, `personality_notes: "3일 써보고 아니면 삭제"`) 가 "설치 후 첫 10분 안에 코칭 탭 샘플이 내 프로필과 무관한 generic 문구 → '그거면 ChatGPT 쓰지' 결론 → 이탈" 하는 경로를 막는다. 해결책은 템플릿 수 확장이 아니라 **온보딩 값(gender/height/goal/bodyType) + 최근 7일 로컬 세션**을 문구에 직접 박아 ChatGPT 대비 **"내 입력 반영" 증거**를 확보하는 것.

### 구현 요구사항

#### 1) `Mofit/Views/Coaching/CoachingSamples.swift` — 전면 교체

파일 전체를 아래 내용으로 교체한다. `struct CoachingSample` 은 기존 시그니처 그대로 보존 (`CoachingView.sampleFeedbackCard(sample:)` 가 이 타입에 의존). `enum CoachingSamples` 는 완전히 제거. 새로 `CoachingGenInput`, `CoachingGenSession`, `CoachingSampleGenerator` 3 개 struct 추가.

```swift
// iter 7 (task 6-coaching-generator): static samples → dynamic generator.
// `enum CoachingSamples.all` 정적 하드코딩 제거. `CoachingSampleGenerator` 가 온보딩 값 + 최근 7일 로컬 세션 기반으로 결정론적 생성 (spec §2.7, ADR-006 2026-04-24 업데이트).
// Foundation-only. SwiftData / UIKit / 네트워크 / 랜덤 사용 금지.

import Foundation

struct CoachingSample: Identifiable {
    let id = UUID()
    let type: String   // "pre" | "post"
    let content: String
}

struct CoachingGenSession {
    let startedAt: Date
    let endedAt: Date
    let totalDuration: Int
    let repCounts: [Int]

    var totalReps: Int { repCounts.reduce(0, +) }
}

struct CoachingGenInput {
    let gender: String
    let height: Double
    let weight: Double
    let bodyType: String
    let goal: String
    let recentSessions: [CoachingGenSession]
}

struct CoachingSampleGenerator {
    static func generate(input: CoachingGenInput, now: Date) -> [CoachingSample] {
        let calendar = Calendar.current
        let windowStart = calendar.startOfDay(for: now).addingTimeInterval(-6 * 86400)
        let windowed = input.recentSessions
            .filter { $0.startedAt >= windowStart && $0.startedAt <= now && $0.totalReps > 0 }
            .sorted { $0.startedAt < $1.startedAt }

        let totalReps = windowed.reduce(0) { $0 + $1.totalReps }
        let sessionCount = windowed.count
        let latestSets = windowed.last?.repCounts ?? []
        let hasRecords = sessionCount > 0

        let preContent = preText(
            input: input,
            hasRecords: hasRecords,
            totalReps: totalReps,
            sessionCount: sessionCount
        )
        let postContent = postText(
            input: input,
            hasRecords: hasRecords,
            totalReps: totalReps,
            sessionCount: sessionCount,
            latestSets: latestSets
        )

        return [
            CoachingSample(type: "pre", content: preContent),
            CoachingSample(type: "post", content: postContent)
        ]
    }

    // MARK: - Pre templates (goal 3 × kind 1 = 3 of 6 base)

    private static func preText(
        input: CoachingGenInput,
        hasRecords: Bool,
        totalReps: Int,
        sessionCount: Int
    ) -> String {
        let genderLabel = genderKorean(input.gender)
        let heightStr = formatHeight(input.height)
        let targetReps = recommendedReps(goal: input.goal, bodyType: input.bodyType)

        switch input.goal {
        case "weightLoss":
            if hasRecords {
                return "\(genderLabel)/\(heightStr)cm/감량 목표. 최근 7일 \(sessionCount)회 운동으로 총 \(totalReps)회 스쿼트를 쌓으셨습니다. 오늘도 \(targetReps)회를 겨냥해 칼로리 소모 페이스를 이어가세요."
            } else {
                return "\(genderLabel)/\(heightStr)cm/감량 목표. 첫 스쿼트는 \(targetReps)회로 가볍게 시작해보세요. 쉬지 않고 완주하는 것보다 자세를 유지하는 것이 우선입니다."
            }
        case "strength":
            if hasRecords {
                return "\(genderLabel)/\(heightStr)cm/근력 목표. 최근 7일 \(sessionCount)회 · 총 \(totalReps)회를 수행했습니다. 오늘은 세트당 \(targetReps)회, 하단에서 1초 정지로 근육 자극을 키워보세요."
            } else {
                return "\(genderLabel)/\(heightStr)cm/근력 목표. 첫 세트는 \(targetReps)회로 시작하고 하단에서 1초 멈추면 자극이 커집니다."
            }
        case "bodyShape":
            if hasRecords {
                return "\(genderLabel)/\(heightStr)cm/체형 개선 목표. 최근 7일 \(sessionCount)회 · 총 \(totalReps)회 진행. 오늘은 \(targetReps)회로 하체 라인 유지를 이어가세요."
            } else {
                return "\(genderLabel)/\(heightStr)cm/체형 개선 목표. 첫 세트는 \(targetReps)회, 엉덩이가 먼저 내려가는 감각에 집중해보세요."
            }
        default:
            if hasRecords {
                return "\(genderLabel)/\(heightStr)cm. 최근 7일 \(sessionCount)회 · 총 \(totalReps)회. 오늘도 \(targetReps)회 도전해보세요."
            } else {
                return "\(genderLabel)/\(heightStr)cm. 첫 스쿼트는 \(targetReps)회로 시작해보세요."
            }
        }
    }

    // MARK: - Post templates (goal 3 × kind 1 = 3 of 6 base)

    private static func postText(
        input: CoachingGenInput,
        hasRecords: Bool,
        totalReps: Int,
        sessionCount: Int,
        latestSets: [Int]
    ) -> String {
        switch input.goal {
        case "weightLoss":
            if hasRecords, !latestSets.isEmpty {
                let setsTotal = latestSets.reduce(0, +)
                let setsStr = formatSets(latestSets)
                return "감량 목표 기준 최근 세션 \(latestSets.count)세트 총 \(setsTotal)회(\(setsStr)). 최근 7일 누적 \(totalReps)회로 칼로리 소모 곡선이 꾸준합니다. 내일은 마지막 세트에서 쉬는 시간 15초 늘려 심박수 유지해보세요."
            } else {
                return "감량 목표. 아직 기록이 없네요. 다음 세션은 10회 3세트를 목표로 쉬는 시간 30초로 짧게 유지해 심박수를 올려보세요."
            }
        case "strength":
            if hasRecords, !latestSets.isEmpty {
                let setsTotal = latestSets.reduce(0, +)
                let setsStr = formatSets(latestSets)
                return "근력 목표 기준 최근 세션 \(latestSets.count)세트 총 \(setsTotal)회(\(setsStr)). 최근 7일 누적 \(totalReps)회. 내일은 첫 세트를 2회 줄이고 마지막 세트에서 1회 더 짜내 총량 유지해보세요."
            } else {
                return "근력 목표. 아직 기록이 없네요. 다음 세션은 8회 3세트, 쉬는 시간 90초로 강도를 확보해보세요."
            }
        case "bodyShape":
            if hasRecords, !latestSets.isEmpty {
                let setsTotal = latestSets.reduce(0, +)
                let setsStr = formatSets(latestSets)
                return "체형 개선 목표 기준 최근 세션 \(latestSets.count)세트 총 \(setsTotal)회(\(setsStr)). 최근 7일 누적 \(totalReps)회. 내일은 각 세트 마지막 2회에서 하강 속도를 3초로 늘려 하체 라인을 다잡아보세요."
            } else {
                return "체형 개선 목표. 아직 기록이 없네요. 다음 세션은 12회 3세트, 하강을 3초로 천천히 내리면 하체 라인에 자극이 들어옵니다."
            }
        default:
            if hasRecords, !latestSets.isEmpty {
                let setsTotal = latestSets.reduce(0, +)
                let setsStr = formatSets(latestSets)
                return "최근 세션 \(latestSets.count)세트 총 \(setsTotal)회(\(setsStr)). 최근 7일 누적 \(totalReps)회."
            } else {
                return "아직 기록이 없네요. 다음 세션은 10회부터 시작해보세요."
            }
        }
    }

    // MARK: - Interpolation helpers

    private static func genderKorean(_ g: String) -> String {
        switch g {
        case "female": return "여성"
        case "male": return "남성"
        default: return g
        }
    }

    private static func formatHeight(_ h: Double) -> String {
        String(format: "%.0f", h)
    }

    private static func recommendedReps(goal: String, bodyType: String) -> Int {
        switch (goal, bodyType) {
        case ("weightLoss", "chubby"): return 15
        case ("weightLoss", _): return 12
        case ("strength", "slim"): return 8
        case ("strength", _): return 10
        case ("bodyShape", _): return 12
        default: return 10
        }
    }

    private static func formatSets(_ sets: [Int]) -> String {
        sets.enumerated().map { "\($0.offset + 1)세트 \($0.element)회" }.joined(separator: " → ")
    }
}
```

**핵심 제약**:
- 파일 최상단 1줄 코멘트 필수 (`// iter 7 (task 6-coaching-generator): static samples → dynamic generator.`) — grep 가드 대상 아니지만 git blame 추적용.
- `import Foundation` 만. `import SwiftData` / `import SwiftUI` / `import UIKit` / `import Vision` / `import AVFoundation` 전부 금지.
- `@Model` / `@Query` / `@Published` / `ObservableObject` 사용 금지.
- `UserProfile` / `WorkoutSession` / `ModelContext` / `Date.init()` 파라미터 없는 호출(현재 시간 의존) 금지 — `now: Date` 를 항상 명시적 주입.
- 랜덤 호출(`Int.random`, `Bool.random`, `shuffled()`) 금지 — 결정론.
- 반환 = **항상 2개** (pre 1 + post 1). 카운트 변경 금지.
- 템플릿 base = **6개** (goal 3 × kind 2). 내부 `switch input.goal` 에 `case "weightLoss" | "strength" | "bodyShape" | default` 4가지 branch, 각 `hasRecords` true/false 분기 = 6 base + default 2 fallback. default fallback 은 "테스트 결정론" 방어용으로 허용하며 템플릿 수 산정에서 제외(프로필이 이 3 enum 값을 벗어나지 않음).

#### 2) `Mofit/Views/Coaching/CoachingView.swift` — 부분 수정

##### 2-a) `notLoggedInContent` 내부 `ForEach` 블록 교체

기존 L144~152:

```swift
                VStack(alignment: .leading, spacing: 12) {
                    Text("이런 피드백을 받게 됩니다")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)

                    ForEach(CoachingSamples.all) { sample in
                        sampleFeedbackCard(sample: sample)
                    }
                }
                .padding(.horizontal, 16)
```

를 아래로 교체:

```swift
                VStack(alignment: .leading, spacing: 12) {
                    Text("이런 피드백을 받게 됩니다")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)

                    if let profile = profile {
                        let samples = CoachingSampleGenerator.generate(
                            input: makeGenInput(profile: profile, sessions: Array(sessions)),
                            now: Date()
                        )
                        ForEach(samples) { sample in
                            sampleFeedbackCard(sample: sample)
                        }
                    } else {
                        onboardingCTACard
                    }
                }
                .padding(.horizontal, 16)
```

- `profile` 은 이미 L19~21 computed (`profiles.first`). `sessions` 은 이미 L9 `@Query`. 새 `@Query` 선언 추가 금지.

##### 2-b) 새 private helper 2개 추가

`sampleFeedbackCard(sample:)` 메서드(L193~214) 의 `}` 직후, `coachStyleLabel` (L216 부근) **앞** 에 아래 2개 helper 추가:

```swift
    private func makeGenInput(profile: UserProfile, sessions: [WorkoutSession]) -> CoachingGenInput {
        CoachingGenInput(
            gender: profile.gender,
            height: profile.height,
            weight: profile.weight,
            bodyType: profile.bodyType,
            goal: profile.goal,
            recentSessions: sessions.map { session in
                CoachingGenSession(
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    totalDuration: session.totalDuration,
                    repCounts: session.repCounts
                )
            }
        )
    }

    private var onboardingCTACard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundColor(Theme.neonGreen)
                Text("온보딩을 먼저 완료해주세요")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
            }

            Text("프로필 정보가 있어야 맞춤 샘플 피드백을 만들어 드려요.")
                .font(.footnote)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
```

- `Theme.neonGreen` / `Theme.textPrimary` / `Theme.textSecondary` / `Theme.cardBackground` 모두 기존 사용 중인 심볼. 신규 Theme 토큰 추가 금지.
- `onboardingCTACard` 는 disclaimer 문구(`※ 예시 피드백 …`) 를 **넣지 않는다** — 이 카드는 "샘플"이 아니라 "CTA". sampleFeedbackCard 와 구분.
- `Image(systemName:)` 의 icon 은 SF Symbol 기본 제공. 추가 asset 금지.

##### 2-c) 나머지 경로 불변 검증 (수정 금지, 읽기로만)

다음 경로는 이번 phase scope 외. 한 줄도 건드리지 마라:

- `loggedInContent` (L116~129)
- `isToday(dateString:)` (L44~56)
- `loadServerFeedbacks()` (L101~114)
- `headerSection` / `buttonSection` / `feedbackButton` / `feedbackList` / `localFeedbackList` / `serverFeedbackList` / `serverFeedbackCard` / `formatServerDate` / `emptyState` / `errorCard` / `feedbackCard` / `typeBadge` / `formatDate` / `requestFeedback` / `coachStyleLabel`
- 로그인/회원가입 버튼 `Button { showLogin = true }` / `showSignUp` 블록
- `.fullScreenCover` / `.task` / `.onChange` / `.onAppear` modifier

`sampleFeedbackCard(sample:)` 의 본문(type badge, content Text, disclaimer Text) 도 불변 — 새 generator 가 `CoachingSample { id, type, content }` 시그니처 그대로 반환하므로 호환.

#### 3) `project.yml` — MofitTests target 추가 + test scheme 추가

현재 `project.yml` 구조 (참조):

```yaml
name: Mofit
options: { ... }
settings: { ... }
targets:
  Mofit:
    type: application
    ...
    settings: { ... }
    dependencies: [ ... ]
schemes:
  Mofit:
    build:
      targets:
        Mofit: all
    run:
      config: Debug
    archive:
      config: Release
```

아래 2개 수정 수행:

##### 3-a) `targets:` 아래에 `Mofit:` 블록 **뒤** 에 `MofitTests:` 블록 추가

`Mofit:` target 의 마지막 라인(`      - sdk: Security.framework`) 다음에 빈 줄 없이 아래 블록 그대로 append:

```yaml

  MofitTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: MofitTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.mofit.tests
        GENERATE_INFOPLIST_FILE: YES
        IPHONEOS_DEPLOYMENT_TARGET: "17.0"
    dependencies:
      - target: Mofit
```

- `type: bundle.unit-test` — xcodegen 이 host app 을 요구하는 test bundle 생성.
- `platform: iOS` 명시. `dependencies: - target: Mofit` 이 host app 연결 + `@testable import Mofit` 가능하게 한다.
- `sources: - path: MofitTests` — 같은 이름 디렉토리(아직 빈 상태. 바로 아래 4) 에서 파일 생성) 에서 `.swift` 글롭.
- `PRODUCT_BUNDLE_IDENTIFIER` 는 `com.mofit.tests` 로 고정.

##### 3-b) `schemes:` 아래 `Mofit:` 블록에 `test:` action 추가

기존 `schemes.Mofit.archive.config: Release` 다음(파일의 마지막 의미 라인) 에 아래 블록을 append:

```yaml
    test:
      config: Debug
      targets:
        - MofitTests
```

- 결과: `Mofit` scheme 에 build / run / archive / **test** 4개 action. `xcodebuild -scheme Mofit test` 로 호출 가능.

##### 3-c) MofitTests 를 위한 별도 scheme 생성 금지

`schemes.MofitTests:` 블록을 따로 만들지 마라. `Mofit` scheme 1개에 test action 을 포함하는 구조 유지.

#### 4) `MofitTests/CoachingSampleGeneratorTests.swift` — 신규 생성

**먼저 디렉토리 생성**: 아래 커맨드로 디렉토리부터 만든다.

```bash
mkdir -p MofitTests
```

그 후 아래 내용을 정확히 담은 파일을 생성한다.

```swift
import XCTest
@testable import Mofit

final class CoachingSampleGeneratorTests: XCTestCase {

    func test_generate_emptySessions_containsProfileInterpolation() {
        let input = CoachingGenInput(
            gender: "female",
            height: 160,
            weight: 55,
            bodyType: "normal",
            goal: "weightLoss",
            recentSessions: []
        )
        let samples = CoachingSampleGenerator.generate(input: input, now: Date())
        XCTAssertEqual(samples.count, 2)
        XCTAssertTrue(samples.allSatisfy { $0.type == "pre" || $0.type == "post" })
        let combined = samples.map(\.content).joined()
        XCTAssertTrue(
            combined.contains("여성") || combined.contains("160") || combined.contains("감량"),
            "출력에 '여성' / '160' / '감량' 중 하나 이상 포함되어야 한다. 실제: \(combined)"
        )
    }

    func test_generate_oneSessionWith17Reps_postContains17() {
        let now = Date()
        let session = CoachingGenSession(
            startedAt: now.addingTimeInterval(-60),
            endedAt: now,
            totalDuration: 60,
            repCounts: [17]
        )
        let input = CoachingGenInput(
            gender: "female",
            height: 160,
            weight: 55,
            bodyType: "normal",
            goal: "weightLoss",
            recentSessions: [session]
        )
        let samples = CoachingSampleGenerator.generate(input: input, now: now)
        let post = samples.first { $0.type == "post" }
        XCTAssertNotNil(post, "post 샘플이 반환되어야 한다")
        XCTAssertTrue(
            post!.content.contains("17"),
            "post 샘플에 '17' 포함되어야 한다 (총 rep 17회). 실제: \(post?.content ?? "nil")"
        )
    }
}
```

- **`gender: "female"`** (한국어 "여성" 이 아니라 enum raw). generator 내부 `genderKorean` 이 "female" → "여성" 변환. 테스트 케이스 1 의 assertion 은 변환된 "여성" 을 substring 검색.
- **`repCounts: [17]`** — "10" 이 아니라 "17". 이유: 프로필의 `height=160` / `weight=55` / `samples.count==2` 와의 substring false positive 를 피하기 위함 (height 의 "0"/"1" 중첩, weight 의 "5" 중첩). 17 은 프로필 숫자와 겹치지 않는 prime.
- **CTO 조건 1 원문에는 "10" 이 기재**되어 있지만, tech-critic-lead 의 조건부 승인 (agentId ae9d11bf571456ddd) 에서 **"프로필 숫자와 겹치지 않는 값(예: 17)" 으로 변경** 지시 받음. 이 변경은 재승인 불필요 (테스트 결정론 개선 방향).
- **테스트 2개만**. pre/post 분리 확인 / 기록 없음 케이스 / goal 3-way / bodyType 조정자 등 추가 테스트 **금지** (CTO 조건 1 "XCTest 2 케이스를 CI 통과 조건" 엄수).
- `import Mofit` 이 아니라 **`@testable import Mofit`** — `CoachingGenInput` / `CoachingGenSession` / `CoachingSampleGenerator` / `CoachingSample` 전부 `internal` 접근 제어자 유지 (public 노출 금지).

#### 5) xcodegen generate

위 1~4 변경 완료 후 아래 실행:

```bash
xcodegen generate
```

- `project.yml` glob 기반이라 `MofitTests` 디렉토리 1개 + `.swift` 1 파일이 추가되어 pbxproj 재생성 diff 가 발생한다 (target, scheme, file ref 추가).

### 구현 후 코드 트레이스 검증 (MofitTests 자동 테스트와 병행)

XCTest 가 자동 검증하지만, AC 실행 전에 아래 3개 시나리오를 에이전트가 코드 흐름으로도 수학적으로 검증하라:

1. **테스트 1 — 프로필 인터폴레이션 (sessions=[])**: `genderLabel="여성"`, `heightStr="160"`, `targetReps=12` (weightLoss/normal). hasRecords=false. preText → `"여성/160cm/감량 목표. 첫 스쿼트는 12회로 가볍게…"`. postText → `"감량 목표. 아직 기록이 없네요. 다음 세션은 10회 3세트…"`. combined 에 "여성", "160", "감량" 모두 포함. assertion pass.
2. **테스트 2 — 1세션 17회 (sessions=[repCounts=[17]])**: session.startedAt=now-60, window=now-6d~now 내. totalReps=17, sessionCount=1, latestSets=[17]. postText(weightLoss/normal/hasRecords=true) → `"감량 목표 기준 최근 세션 1세트 총 17회(1세트 17회). 최근 7일 누적 17회로…"`. `.contains("17")` pass.
3. **7일 경계 테스트 (AC 외, 설계 검증)**: session.startedAt=now-7.5d. windowStart=now.startOfDay-6d. 이 세션은 windowStart 보다 앞이므로 filter 에서 제외. sessionCount=0, hasRecords=false 분기로 빠짐. OK.

불일치 시 구현 수정. 특히 `Calendar.current.startOfDay(for:) - 6*86400` 의 경계 산술, `genderKorean` 의 default branch, `recommendedReps` 의 분기 우선순위를 재확인.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0 이어야 한다.

```bash
# 1) CoachingSamples.swift — 교체 결과 검증
grep -F 'iter 7 (task 6-coaching-generator): static samples → dynamic generator' Mofit/Views/Coaching/CoachingSamples.swift
grep -F 'struct CoachingSample: Identifiable' Mofit/Views/Coaching/CoachingSamples.swift
grep -F 'struct CoachingGenSession' Mofit/Views/Coaching/CoachingSamples.swift
grep -F 'struct CoachingGenInput' Mofit/Views/Coaching/CoachingSamples.swift
grep -F 'struct CoachingSampleGenerator' Mofit/Views/Coaching/CoachingSamples.swift
grep -F 'static func generate(input: CoachingGenInput, now: Date) -> [CoachingSample]' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'enum CoachingSamples' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'static let all:' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F '지난 주 3일 운동 · 총 78회 스쿼트' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F '오늘 3세트 총 32회' Mofit/Views/Coaching/CoachingSamples.swift

# 2) CoachingSamples.swift — Foundation-only 제약
grep -F 'import Foundation' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'import SwiftData' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'import SwiftUI' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'import UIKit' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F '@Model' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F '@Query' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'UserProfile' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'WorkoutSession' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'ModelContext' Mofit/Views/Coaching/CoachingSamples.swift

# 3) CoachingSamples.swift — 금지 카피
! grep -F '곧 지원' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F '조만간' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F '로드맵' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F '로그인하면' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F '가입하면' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'Claude' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'ChatGPT' Mofit/Views/Coaching/CoachingSamples.swift

# 4) CoachingSamples.swift — 결정론 확보 (랜덤 호출 금지)
! grep -F '.random' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F '.shuffled' Mofit/Views/Coaching/CoachingSamples.swift
! grep -F 'Date()' Mofit/Views/Coaching/CoachingSamples.swift  # generator 는 now: Date 주입받음. Date() 리터럴 호출 금지.

# 5) CoachingView.swift — generator 호출 + adapter + 폴백 CTA
grep -F 'CoachingSampleGenerator.generate(' Mofit/Views/Coaching/CoachingView.swift
grep -F 'makeGenInput(profile:' Mofit/Views/Coaching/CoachingView.swift
grep -F 'CoachingGenInput(' Mofit/Views/Coaching/CoachingView.swift
grep -F 'CoachingGenSession(' Mofit/Views/Coaching/CoachingView.swift
grep -F '온보딩을 먼저 완료해주세요' Mofit/Views/Coaching/CoachingView.swift
grep -F 'onboardingCTACard' Mofit/Views/Coaching/CoachingView.swift
grep -F '프로필 정보가 있어야 맞춤 샘플 피드백' Mofit/Views/Coaching/CoachingView.swift

# 6) CoachingView.swift — 구 API 제거 + disclaimer 유지 + 로그인 유도 카피 금지
! grep -F 'CoachingSamples.all' Mofit/Views/Coaching/CoachingView.swift
grep -F '※ 예시 피드백 (실제 데이터 기반으로 매번 다름)' Mofit/Views/Coaching/CoachingView.swift
! grep -F '로그인하면 Claude' Mofit/Views/Coaching/CoachingView.swift
! grep -F '로그인하면 더' Mofit/Views/Coaching/CoachingView.swift
! grep -F '가입하면 더' Mofit/Views/Coaching/CoachingView.swift

# 7) CoachingView.swift — 새 @Query 선언 추가 금지 (기존 3개: feedbacks(sort 버전) + profiles + sessions)
test "$(grep -cE '^\s*@Query' Mofit/Views/Coaching/CoachingView.swift)" -eq 3

# 8) 기존 CoachingViewModel 불변
git diff --quiet HEAD -- Mofit/ViewModels/CoachingViewModel.swift

# 9) project.yml — MofitTests target 추가 + test scheme 추가
grep -F 'MofitTests:' project.yml
grep -F 'type: bundle.unit-test' project.yml
grep -F 'PRODUCT_BUNDLE_IDENTIFIER: com.mofit.tests' project.yml
grep -A 10 'MofitTests:' project.yml | grep -F 'target: Mofit'
grep -A 2 '    test:' project.yml | grep -F '- MofitTests'

# 10) MofitTests 파일 존재 + 내용 검증
test -d MofitTests
test -f MofitTests/CoachingSampleGeneratorTests.swift
grep -F '@testable import Mofit' MofitTests/CoachingSampleGeneratorTests.swift
grep -F 'final class CoachingSampleGeneratorTests: XCTestCase' MofitTests/CoachingSampleGeneratorTests.swift
grep -F 'func test_generate_emptySessions_containsProfileInterpolation()' MofitTests/CoachingSampleGeneratorTests.swift
grep -F 'func test_generate_oneSessionWith17Reps_postContains17()' MofitTests/CoachingSampleGeneratorTests.swift
grep -F 'repCounts: [17]' MofitTests/CoachingSampleGeneratorTests.swift
grep -F 'post!.content.contains("17")' MofitTests/CoachingSampleGeneratorTests.swift
grep -F 'combined.contains("여성") || combined.contains("160") || combined.contains("감량")' MofitTests/CoachingSampleGeneratorTests.swift
# 테스트 2개만 (XCTestCase 메서드는 'func test' 접두 2개 초과 금지)
test "$(grep -cE '^\s+func test_' MofitTests/CoachingSampleGeneratorTests.swift)" -eq 2

# 11) 변경 범위 — Mofit/ 하위 정확히 2개 파일
CHANGED_MOFIT=$(git diff --name-only HEAD -- Mofit/ | sort)
EXPECTED_MOFIT=$(printf 'Mofit/Views/Coaching/CoachingSamples.swift\nMofit/Views/Coaching/CoachingView.swift\n' | sort)
test "$CHANGED_MOFIT" = "$EXPECTED_MOFIT"

# 12) 모델 / 서비스 / 카메라 / 다른 View 전부 불변
git diff --quiet HEAD -- Mofit/Models/
git diff --quiet HEAD -- Mofit/Services/
git diff --quiet HEAD -- Mofit/Camera/
git diff --quiet HEAD -- Mofit/App/
git diff --quiet HEAD -- Mofit/Views/Home/
git diff --quiet HEAD -- Mofit/Views/Onboarding/
git diff --quiet HEAD -- Mofit/Views/Profile/
git diff --quiet HEAD -- Mofit/Views/Records/
git diff --quiet HEAD -- Mofit/Views/Tracking/
git diff --quiet HEAD -- Mofit/Utils/
git diff --quiet HEAD -- Mofit/Config/

# 13) docs / server / scripts / README 불변
git diff --quiet HEAD -- docs/ server/ scripts/ README.md

# 14) 신규 파일 금지 범위
test ! -f Mofit/Views/Coaching/CoachingGeneratorViewModel.swift
test ! -f Mofit/ViewModels/CoachingSampleGeneratorViewModel.swift
test ! -f Mofit/Services/CoachingSampleGenerator.swift
# MofitTests/ 안에는 1 파일만
test "$(find MofitTests -type f -name '*.swift' | wc -l | tr -d ' ')" -eq 1

# 15) xcodegen 재생성 + xcodebuild build 성공
xcodegen generate
xcodebuild \
  -scheme Mofit \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -80

# 16) xcodebuild test 성공 — destination 동적 선택 (iPhone simulator 중 하나 사용, 실패 시 iPhone 15 폴백)
SIMULATOR_NAME=$(xcrun simctl list devices available --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d.get('isAvailable') and 'iPhone' in d.get('name', ''):
            print(d['name'])
            sys.exit(0)
" 2>/dev/null)
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
echo "Using simulator: ${SIMULATOR_NAME}"
xcodebuild \
  -scheme Mofit \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  test \
  | tail -120
```

xcodebuild build 출력 말미에 `** BUILD SUCCEEDED **` 가 찍혀야 하고, xcodebuild test 출력 말미에 `** TEST SUCCEEDED **` 가 찍혀야 한다.

AC 15 와 16 둘 다 성공해야 한다 (build 는 generic destination 으로, test 는 concrete simulator destination 으로 분리 실행). xcrun simctl 이 없거나 사용 가능한 simulator 가 전혀 없으면 로그를 `error_message` 에 기록 후 에러 상태로 기록.

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `tasks/6-coaching-generator/index.json` 의 phase 1 status 를 `"completed"` 로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"` 로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

xcodebuild test 가 simulator runtime 부재로 실패할 경우:
- `xcrun simctl list runtimes` 로 설치된 runtime 확인.
- 사용 가능 device 가 전무하면 `xcrun simctl create "iPhone 15" "iPhone 15" "iOS 17.0"` 로 생성 시도 (iOS 17 runtime 이 설치돼 있어야 함).
- 그래도 안 되면 error 기록 후 중단 — 테스트 인프라 부재는 이번 task 의 AC 18 scope 외 (`docs/testing.md` 의 "CI 실행" 섹션에서 "destination 동적 선택" 방식 제안. 추후 인프라 정비 별건).

## 주의사항

- **`CoachingSample` 타입 시그니처 불변**: 필드 `id: UUID`, `type: String`, `content: String` 세 개만. `Identifiable` 준수. `CoachingView.sampleFeedbackCard(sample:)` 가 이 타입에 의존 — 필드 추가/삭제 금지.
- **로그인 유저 경로 완전 불변**: `loggedInContent`, `requestFeedback`, `loadServerFeedbacks`, `CoachingViewModel`, `POST /coaching/request` 서버 호출, Claude API 프록시 전부 건드리지 마라 (ADR-006, ADR-012, ADR-013 유지).
- **disclaimer 카피 불변**: `"※ 예시 피드백 (실제 데이터 기반으로 매번 다름)"` 그대로. 변경 금지. 추가 카피 삽입 금지.
- **로그인 유도 문구 금지** (CTO 조건 3): "로그인하면 Claude AI 더 정교…" / "가입하면 더 많은…" / "프리미엄 기능" 등 전부 금지. `notLoggedInContent` 에 이미 로그인/회원가입 버튼이 있으므로 추가 유도 문구 불필요.
- **정적 샘플 폴백 금지** (CTO 조건 4): 프로필 nil 시 기존 하드코딩 카피("지난 주 3일 운동…", "오늘 3세트 총 32회…") 를 **재현하는 어떤 문자열도** 추가하지 마라. `onboardingCTACard` 는 "샘플" 이 아니라 "CTA" — disclaimer 포함 금지.
- **템플릿 수 = 6 엄수** (CTO 조건 2): `goal (weightLoss/strength/bodyShape) × kind (pre/post) = 6`. `generatePre` 의 `switch input.goal` 3 branch + `generatePost` 의 3 branch + 각각의 `hasRecords` 인터폴레이션 분기 = 6 base + default 2 (방어용). default 는 실무 enum 범위 밖이라 템플릿 개수 산정에서 제외. **10 초과 시 CTO 재승인 티켓** 필요.
- **인터폴레이션 슬롯 = 3 이하**: (a) `totalReps` 합, (b) `sessionCount`, (c) post 한정 `latestSets`. "최다요일" / "일평균 증감" / "주간 트렌드" 등 고급 집계는 **이번 scope 외** (재승인 티켓). `Calendar.current.component(.weekday)` 호출 금지.
- **Foundation-only 엄수**: `CoachingSamples.swift` 안에 `import Foundation` 외 어떤 import 도 금지. `CoachingView.swift` 에서 generator 호출 시 Foundation 외 의존 추가 금지.
- **스키마 변경 금지**: `UserProfile` 에 `onboardingCompleted: Bool` 필드 추가 금지. `@AppStorage` 키로 관리 중이며 `CoachingView` 도달 시점엔 `true` 가 보장됨. `profile == nil` 단일 체크만으로 폴백 판정.
- **MofitTests 확장 금지**: 이번 phase 에서 `MofitTests/` 안에 `CoachingSampleGeneratorTests.swift` **외 다른 `.swift` 파일 생성 금지**. AC 10 의 `find MofitTests -type f -name '*.swift' | wc -l` 가 1 이어야 한다. 다른 모듈의 회고 테스트 추가는 scope creep.
- **xcodegen 재생성 후 pbxproj 수동 편집 금지**: Xcode 에서 파일을 손으로 추가한 것처럼 pbxproj 를 편집하지 마라. xcodegen 생성본 그대로 커밋.
- **`onboardingCompleted` 기술 정정 금지**: `docs/data-schema.md:14` 에 남아 있는 구형 기술(`UserProfile` 필드로 표기) 은 이번 task scope 밖. 건드리지 마라.
- **`AuthGateView` 파일 이름 재정비 금지**: 파일 실체는 `CoachingView.notLoggedInContent` 이지만 docs 상 명칭은 `AuthGateView`. 이번 phase 는 문서/실체 간 명명 괴리 그대로 둔다 (별건 정리 티켓).
- **MofitTests target bundle id 고정**: `com.mofit.tests`. 다른 값 사용 시 Xcode 의 host app matching 에 영향. 변경 금지.
- **test scheme 구성 변경 금지**: `Mofit` scheme 1개에 `test` action 만 append. `MofitTests` 전용 scheme 별도 생성 금지 (CLI 커맨드 라인 간결화).
- **기존 테스트를 깨뜨리지 마라**: 이전에 `MofitTests` 가 없었으므로 직접 깰 것은 없다. `xcodebuild build` 경고 증가 시 즉시 해결. 이번 phase 변경 scope 안에서 cleanup 포함.
- **git status 클린 상태 시작**: dirty 면 error 기록 후 중단.
- **실기기 QA 없음** (CTO 조건 1): XCTest 자동 검증으로 완결. `docs/user-intervention.md` 수정 금지.
