# Phase 0: docs

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다.

```bash
git status --porcelain -- docs/ Mofit/ project.yml README.md MofitTests/ tasks/6-coaching-generator/
```

출력되는 파일이 있으면 working tree 가 더럽다. 진행하지 말고 `tasks/6-coaching-generator/index.json` 의 phase 0 status 를 `"error"` 로 변경, `error_message` 에 `dirty working tree before phase 0` 로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/prd.md` — 가치제안 §2.5 AI 코칭 탭 (비로그인 샘플 2종 하드코딩 기술이 이번 task delta 대상)
- `docs/spec.md` — §1 탭/화면 구성, §2 핵심 상태머신, §3 데이터 모델 (특히 `UserProfile`, `WorkoutSession.repCounts`), §5 네트워킹 분기 테이블
- `docs/adr.md` — **ADR-006** (AI 코칭 context 7일 제한 — 이번 task 가 비로그인 분기 delta 업데이트 대상), ADR-013(로그인/비로그인 분기 — 이번 task 존중), ADR-017(스쿼트 전용 포지셔닝), ADR-018(diagnostic hint 전례)
- `docs/code-architecture.md` — `Views/Coaching/` + `ViewModels/CoachingViewModel.swift` 배치. 이번 task 는 **pure struct generator** 를 `Views/Coaching/CoachingSamples.swift` 파일 내부에 둠 (신규 ViewModel 금지).
- `docs/testing.md` — 3줄 원칙. 이 task 에서 **`MofitTests` 타겟 신설 허용** (iter 7 CTO 조건 1 에 의거 task 0~5 선례 명시적 폐기).
- `docs/user-intervention.md` — 기존 §트래킹 진단 힌트 / §트래킹 autosave 실기기 QA 항목의 포맷만 참고. **이번 task 는 user-intervention 항목을 추가하지 않는다** (CTO 조건 1: "인간 개입 지점 없음 — XCTest 자동화").
- `docs/data-schema.md` — `UserProfile` 필드(`gender, height, weight, bodyType, goal`) 확인용 읽기 전용. 이번 phase 에서는 **수정 금지**.
- `iterations/7-20260424_224239/requirement.md` — iteration 원문 (§채택된 요구사항, §구현 스케치, §CTO 승인 조건부 4항 — 특히 조건 1(XCTest), 2(템플릿 <=10), 3(로그인 유도 카피 금지), 4(nil 폴백) 가 이번 task 설계의 원전)

그리고 이전 task 전례(Phase 0 docs 업데이트 스타일 참고용):

- `tasks/5-rep-autosave/phase0.md` — 가장 최근 task 의 Phase 0. docs delta 작성 톤/형식 참조.
- `tasks/5-rep-autosave/docs-diff.md` — Phase 0 완료 후 runner 가 자동 생성한 diff.
- `tasks/1-coaching-samples/phase0.md` — 현 `CoachingSamples.swift` 를 최초 도입한 task. 이번 phase 가 **해당 설계를 일부 대체**.

이 Phase 는 **코드 변경 없음**. `docs/` 4개 파일(adr.md, spec.md, code-architecture.md, testing.md)만 수정한다. `Mofit/` · `project.yml` · `README.md` · `server/` · `MofitTests/` 는 터치 금지. `docs/user-intervention.md` · `docs/data-schema.md` · `docs/prd.md` · `docs/flow.md` · `docs/mission.md` 도 터치 금지.

## 작업 내용

### 대상 파일 (정확히 4개)

1. `docs/adr.md` — ADR-006 에 Update 블록 1개 추가 (ADR 신설 금지).
2. `docs/spec.md` — §1.3 화면 목록의 `AuthGateView` 한 줄 기술을 현실화 + §2 에 **§2.7 비로그인 코칭 샘플 생성** 신규 서브섹션 추가.
3. `docs/code-architecture.md` — `Views/Coaching/` 아래에 `CoachingSamples.swift` 설명을 갱신(기존 구조 tree 에 없음 → `Views/Coaching/CoachingView.swift` 옆에 한 줄 추가).
4. `docs/testing.md` — `MofitTests` 타겟 신설 + task 0~5 선례 폐기 명시 섹션 1개 추가.

### 목적

iter 7 persona(`home-workout-newbie-20s`, `risk_preference: conservative`, `trust_with_salesman: 40`, `personality_notes: "3일 써보고 아니면 삭제"`) 가 "설치 후 첫 10분 안에 AI 코칭 차별점을 못 본다 → '그거면 ChatGPT 쓰지' 결론 → 이탈" 하는 경로를 막는다. pain 의 본질은 **"내 입력값이 반영 안 되는 generic 문구"**. 해결책은 템플릿 개수 확장이 아니라 **온보딩 값(gender/height/weight/goal/bodyType) + 최근 7일 로컬 `WorkoutSession` 을 문구에 직접 박는 결정론적 generator**. 이번 Phase 0 는 이 결정을 문서에 박는다.

### 구체 지시

#### 1) `docs/adr.md` — ADR-006 에 Update 블록 1개 추가

기존 ADR-006 섹션(파일 line 33~35 부근, 2줄짜리)은 **불변**. `### ADR-007: 다크모드 고정` 시작 직전(ADR-006 의 마지막 문장 뒤, 빈 줄 뒤) 에 아래 Update 블록을 삽입한다. ADR-019 / ADR-020 등을 **신설하지 말고** ADR-006 안에 Update 블록으로만 추가하라.

```markdown
**2026-04-24 업데이트 (task 6-coaching-generator)**: 비로그인 분기 AI 코칭 샘플은 `CoachingSamples.swift` 내 정적 카피 2종 하드코딩을 제거하고, Foundation-only pure struct `CoachingSampleGenerator` 가 온보딩 값 + 최근 7일 로컬 `WorkoutSession` 기반으로 결정론적 생성.
- 템플릿 수: **6개 base** (goal 3종(weightLoss/strength/bodyShape) × kind 2종(pre/post)). 기록유무(최근 7일 내 `totalReps > 0` 세션 존재 여부) 와 `bodyType` 은 같은 템플릿 내부의 **문자열 인터폴레이션 분기** 로 처리 (템플릿 개수 증분 없음). 10개 한도 엄수 — 초과 시 재승인 티켓.
- 생성 경로: `CoachingView.notLoggedInContent` 가 `@Query UserProfile` + `@Query WorkoutSession` 결과를 Foundation-only intermediate struct(`CoachingGenInput`, `CoachingGenSession`) 로 변환 → `CoachingSampleGenerator.generate(input:now:)` 호출 → `[CoachingSample]`(pre 1 + post 1) 반환. `@Model` 타입을 generator 가 직접 참조하지 않음(테스트 결정론 + SwiftData 의존 격리).
- **프로필 nil(온보딩 미완) 폴백**: 하드코딩 샘플 재사용 **금지**. 카드 자체를 숨기고 "온보딩을 먼저 완료해주세요" CTA 만 노출. 이 폴백이 generic 복귀 경로가 되면 이번 delta 의 목적이 무력화됨.
- 카드 하단 disclaimer 현행 유지 ("※ 예시 피드백 (실제 데이터 기반으로 매번 다름)"). "로그인하면 Claude AI 기반 더 정교한 분석 가능" 유도 문구 **삽입 금지** (비로그인 단계에서 "이거 가짜구나" 역효과).
- 로그인 유저 경로(`POST /coaching/request` → 서버 → Claude API) 및 7일 context 계약은 **완전 불변** (ADR-006 원문 + ADR-012 유지). 이번 update 는 **비로그인 분기 한정**.
- 트레이드오프: (a) 템플릿 결정론 = 동일 입력 → 동일 출력이라 "다양성" 이 없음. 대신 입력(프로필/기록)이 바뀌면 출력이 바뀌므로 "내 상황 반영" 이 ChatGPT 대비 증거가 됨. (b) 7일 외 세션은 집계에서 제외 (ADR-006 원칙 준수). (c) `totalReps == 0` autosave 세션(ADR-009 task 5 delta) 은 기록유무 판정에서도 제외.
- 측정: phase 1 배포 후 차기 iter 시뮬(`ideation` → `persuasion-review`) 에서 keyman 의 "그거면 ChatGPT 쓰지" / "하드코딩 정적 카피" 언급이 report 개선 포인트에서 제거되는지 확인.
```

- Markdown bullet 들여쓰기는 2 space 들여쓰기 금지, 대시 `-` 만.
- 기존 ADR-006 의 "이유" 문장과 이 Update 블록 사이에 빈 줄 1개.
- **ADR-019 / ADR-020 을 새로 만들지 마라.** 파일에 `### ADR-019` 또는 `### ADR-020` 가 추가되면 AC 실패.

#### 2) `docs/spec.md` — §1.3 현실화 + §2.7 신규 서브섹션

##### 2-a) §1.3 `AuthGateView` 한 줄 교체

기존 §1.3 의 `AuthGateView` 한 줄(line 36 부근):

```
- `AuthGateView` — 비로그인 시 코칭 탭에 표시되는 로그인/회원가입 안내 + AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단 노출.
```

을 아래로 교체:

```
- `AuthGateView` — 비로그인 시 코칭 탭에 표시되는 로그인/회원가입 안내 + `CoachingSampleGenerator` 가 온보딩 값 + 최근 7일 로컬 세션 기반으로 동적 생성한 AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단 노출. 프로필 nil 시 카드 숨김 + "온보딩 먼저 완료해주세요" CTA. 상세 §2.7.
```

- 들여쓰기 / dash 유지.

##### 2-b) §2 에 2.7 서브섹션 추가

`### 2.6 트래킹 autosave (비로그인 한정)` 서브섹션의 끝(마지막 bullet 뒤, `---` 구분선 직전) 에 아래 §2.7 통째로 삽입한다.

```markdown
### 2.7 비로그인 코칭 샘플 생성

비로그인 유저가 코칭 탭(`CoachingView.notLoggedInContent`) 진입 시 노출되는 "운동 전/후" 샘플 카드 2장은 정적 하드코딩 카피가 아니라 `CoachingSampleGenerator` 가 **온보딩 값 + 최근 7일 로컬 `WorkoutSession`** 기반으로 결정론적 생성한다 (ADR-006 2026-04-24 업데이트).

- **generator 시그니처**: `CoachingSampleGenerator.generate(input: CoachingGenInput, now: Date) -> [CoachingSample]`. 항상 `pre` 1개 + `post` 1개 (총 2개) 반환. Foundation-only pure struct. async 없음, 네트워크 없음, 랜덤 없음.
- **입력 타입**: `CoachingGenInput` 은 Foundation-only struct. 필드 = `gender: String, height: Double, weight: Double, bodyType: String, goal: String, recentSessions: [CoachingGenSession]`. `@Model` 타입(`UserProfile` / `WorkoutSession`) 을 generator 가 직접 참조하지 않는다 — SwiftData 의존 격리 + 테스트 결정론.
- **adapter 위치**: `CoachingView` 의 `@Query profiles` / `@Query sessions` 결과를 view 내부 helper 에서 `CoachingGenInput` 으로 변환해 generator 호출. adapter 자체는 SwiftData 의존이라 테스트 대상 아님.
- **템플릿 차원**: `goal(3) × kind(2) = 6개 base`. 기록유무(최근 7일 내 `totalReps > 0` 세션 존재 여부) 와 `bodyType`(slim/normal/muscular/chubby) 은 같은 템플릿 내부 인터폴레이션 분기로 처리 (템플릿 개수 증분 없음). **10개 한도 엄수** — 초과 시 ADR-006 Update 블록 재승인 필요.
- **최근 7일 정의**: `Calendar.current.startOfDay(for: now) - 6*86400` 부터 `now` 까지 (오늘 포함). `totalReps > 0` 필터 후 집계. `totalReps == 0` autosave 세션(ADR-009 task 5 delta) 은 제외.
- **인터폴레이션 슬롯 (최대 3개)**: (a) 최근 7일 총 rep 합, (b) 최근 7일 세션 수, (c) post 한정 최신 세션의 `repCounts` 배열. "최다 요일" / "일 평균 증감" / 기타 고급 집계는 **이번 범위 밖** (Phase 2 재승인 대상). 요일 계산은 지역화 이슈로 테스트 결정론 훼손.
- **프로필 nil 폴백**: `@Query profiles.first == nil` 일 때 `CoachingSampleGenerator` 호출 자체를 하지 않고 카드 자리를 "온보딩을 먼저 완료해주세요" CTA 로 대체. 정적 하드코딩 카피 재사용 **금지**. (`onboardingCompleted` 은 `@AppStorage` 키로 관리되며 `UserProfile` 의 필드가 아님 — `CoachingView` 도달 시점엔 `true` 가 보장되므로 nil 체크만으로 충분.)
- **금지 문구**: "로그인하면 Claude AI 기반 더 정교한 분석 가능" / "가입하면 …" 등 **로그인 유도 카피 추가 금지**. 현행 disclaimer "※ 예시 피드백 (실제 데이터 기반으로 매번 다름)" 유지. "곧 지원" / "로드맵" / "조만간" 미래 약속 문구 금지(ADR-017 준수).
- **로그인 유저 경로 불변**: `CoachingView.loggedInContent` 와 `POST /coaching/request` 서버 프록시(ADR-012) 경로는 이번 범위와 무관. generator 는 호출되지 않는다.
- **테스트**: `CoachingSampleGenerator` 는 Foundation-only pure struct 로 추출. iter 7 CTO 조건 1 에 따라 `MofitTests/CoachingSampleGeneratorTests.swift` 2 케이스(프로필 인터폴레이션 포함 / rep 숫자 포함) 가 CI 통과 조건. 실기기 QA 는 **없음** (자동 검증으로 완결).
```

- 삽입 위치: §2.6 마지막 bullet(`0rep 세션` 줄) 뒤 빈 줄 → `### 2.7` h3 → ... → §2.7 마지막 bullet(`테스트`) 뒤 빈 줄 → 기존 `---` 구분선.
- 연속된 h3 사이에 빈 줄 1개 확보.

#### 3) `docs/code-architecture.md` — `Views/Coaching/CoachingView.swift` 옆에 한 줄 추가

기존 디렉토리 tree 의 `Views/Coaching/` 블록은 현재 `│   │   └── CoachingView.swift` 한 줄만 있다. 이 줄을 아래 2줄로 교체한다:

```
│   │   ├── CoachingView.swift
│   │   └── CoachingSamples.swift  # CoachingSample struct + CoachingSampleGenerator (Foundation-only pure, iter 7)
```

- 기존 `│   │   └── CoachingView.swift` 의 `└──` 를 `├──` 로 바꾸고, 그 아래에 새 줄 추가.
- ViewModel 분리 금지 (`CoachingGeneratorViewModel.swift` 등 신규 파일 추가 금지 — 이번 phase 에 docs 에만 반영, phase 1 에서도 동일 원칙).

#### 4) `docs/testing.md` — `MofitTests` 타겟 섹션 신규

기존 `docs/testing.md` 는 원칙 3줄 + 중요 주의 1줄 (line 9) 로 구성. 파일 **끝** 에 빈 줄 1개 후 아래 섹션 통째로 추가하라.

```markdown

---

## XCTest 타겟

`MofitTests` 타겟은 **iter 7(task 6-coaching-generator) 에서 신설**. 이전 task 0~5 의 "MofitTests 타겟 신설 금지" 선례는 **명시적으로 폐기**한다 (iter 7 CTO 조건 1: "실기기 QA 필수화 금지 + XCTest 2케이스 CI 통과 조건").

- **범위**: Foundation-only pure struct 의 회귀 방지용. `@Model` / SwiftData / UIKit / AVFoundation / Vision / 네트워크 의존 코드는 여전히 테스트 대상 아님 (mock 재작성이 구현 중복).
- **현재 유일 대상**: `CoachingSampleGenerator` (Foundation-only, 입력 결정론적). 2 케이스 — (a) 빈 세션 + 프로필 인터폴레이션 포함 확인, (b) rep 수 인터폴레이션 포함 확인.
- **파일 위치**: `MofitTests/<TypeName>Tests.swift` 1파일 1타입. 접근은 `@testable import Mofit` 로 internal 심볼 사용 (public 노출 금지).
- **CI 실행**: `xcodebuild -scheme Mofit test -destination "platform=iOS Simulator,name=<iPhone ...>"`. destination 은 `xcrun simctl list devices available` 결과에서 동적으로 선택하거나 `iPhone 16` 폴백.
- **외부 의존 금지**: Nimble / Quick / Sourcery / Mockingbird 등 테스트 보조 SPM 도입 금지. XCTest 내장만 사용 (ADR-015 외부 의존성 최소화 원칙 유지).
- **확장 정책**: 다른 모듈 회고 테스트는 각 모듈 변경 시점에 함께 추가(원칙 9행 유지). 이 target 을 "전 모듈 커버리지"로 부풀리지 않음.
```

- 기존 파일 끝 line 10 (`- 중요!: 테스트는 해당 모듈 구현 직후 바로 작성한다. 구현 계획에 테스트 작성 시점이 명시된다.`) 는 **불변**. 그 뒤 빈 줄 + `---` + 빈 줄 + 섹션 제목.

### 구현하지 말 것

- **ADR 신설 금지**: `### ADR-019` / `### ADR-020` 추가 금지. ADR-006 Update 블록으로만.
- **`docs/data-schema.md` 수정 금지**: `UserProfile` / `WorkoutSession` 스키마 불변. 구형 기술(`UserProfile.onboardingCompleted`) 은 별건 docs 정리 티켓에서 처리 — 이번 phase 에서 TODO 주석/정정도 추가하지 마라.
- **`docs/user-intervention.md` 수정 금지**: 실기기 QA 항목 신규 추가 금지. CTO 조건 1 에 의거 자동 검증으로 완결. 기존 §트래킹 진단 힌트 / §트래킹 autosave 항목도 터치 금지.
- **`docs/prd.md` · `docs/flow.md` · `docs/mission.md` 수정 금지**: 가치제안 §2.5 의 "샘플 피드백 2종" 표현은 "동적 생성 2종"과 외형 동일(여전히 pre 1 + post 1). README 카피 정돈은 별건.
- **`README.md` · `project.yml` · `Mofit/` · `server/` · `MofitTests/` 수정 금지**: 이번 Phase 는 docs 만. MofitTests 타겟 실제 추가는 phase 1.
- **Mixpanel / AnalyticsService / 신규 이벤트 추가 금지**: 이번 task 는 행동분석 이벤트 신설 대상 아님. `coaching_sample_generated` 같은 유령 이벤트 문서화 금지.
- **"곧 지원" / "로드맵" / "차기 버전" / "조만간" 같은 미래 약속 문구 금지** (ADR-017 원칙 준수).
- **`AuthGateView` 파일 이름 변경 금지**: 문서 상 명칭만 `AuthGateView` 로 지칭됨. 실제 View 구현은 `CoachingView` 의 `notLoggedInContent` private 프로퍼티에 있지만, 문서 레벨의 이름은 유지(phase 1 에서도 파일 rename 없음).

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0 이어야 한다.

```bash
# 1) ADR-006 Update 블록 존재 + ADR-019/020 미신설
grep -F '2026-04-24 업데이트 (task 6-coaching-generator)' docs/adr.md
grep -F 'CoachingSampleGenerator' docs/adr.md
grep -F '템플릿 수: **6개 base**' docs/adr.md
grep -F '프로필 nil(온보딩 미완) 폴백' docs/adr.md
grep -F '"로그인하면 Claude AI 기반 더 정교한 분석 가능" 유도 문구' docs/adr.md
! grep -E '^### ADR-019' docs/adr.md
! grep -E '^### ADR-020' docs/adr.md

# 2) spec.md §1.3 AuthGateView 기술 현실화
grep -F 'CoachingSampleGenerator` 가 온보딩 값 + 최근 7일 로컬 세션 기반으로 동적 생성' docs/spec.md
grep -F '프로필 nil 시 카드 숨김 + "온보딩 먼저 완료해주세요" CTA' docs/spec.md
! grep -F 'AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단 노출.' docs/spec.md

# 3) spec.md §2.7 신규 섹션
grep -F '### 2.7 비로그인 코칭 샘플 생성' docs/spec.md
grep -F 'CoachingSampleGenerator.generate(input: CoachingGenInput, now: Date) -> [CoachingSample]' docs/spec.md
grep -F 'Foundation-only pure struct' docs/spec.md
grep -F 'goal(3) × kind(2) = 6개 base' docs/spec.md
grep -F 'totalReps > 0' docs/spec.md
grep -F '@AppStorage' docs/spec.md
grep -F '온보딩을 먼저 완료해주세요' docs/spec.md
grep -F '※ 예시 피드백 (실제 데이터 기반으로 매번 다름)' docs/spec.md
grep -F 'MofitTests/CoachingSampleGeneratorTests.swift' docs/spec.md

# 4) code-architecture.md 디렉토리 tree 업데이트
grep -F 'CoachingSamples.swift  # CoachingSample struct + CoachingSampleGenerator (Foundation-only pure, iter 7)' docs/code-architecture.md
grep -F '│   │   ├── CoachingView.swift' docs/code-architecture.md
! grep -F '│   │   └── CoachingView.swift' docs/code-architecture.md

# 5) testing.md MofitTests 섹션 추가
grep -F '## XCTest 타겟' docs/testing.md
grep -F '`MofitTests` 타겟은 **iter 7(task 6-coaching-generator) 에서 신설**' docs/testing.md
grep -F 'CoachingSampleGenerator' docs/testing.md
grep -F '@testable import Mofit' docs/testing.md
grep -F 'xcodebuild -scheme Mofit test' docs/testing.md
grep -F 'ADR-015 외부 의존성 최소화 원칙 유지' docs/testing.md

# 6) 로그인 유도 카피 미추가 (docs 전체)
! grep -F '로그인하면 더' docs/spec.md
! grep -F '가입하면 더' docs/spec.md

# 7) 코드/빌드 설정 무변경
git diff --quiet HEAD -- Mofit/ server/ scripts/ README.md project.yml
test ! -d MofitTests

# 8) docs/ 변경 범위 — adr.md + spec.md + code-architecture.md + testing.md 정확히 4개
CHANGED_DOCS=$(git diff --name-only HEAD -- docs/ | sort)
EXPECTED_DOCS=$(printf 'docs/adr.md\ndocs/code-architecture.md\ndocs/spec.md\ndocs/testing.md\n' | sort)
test "$CHANGED_DOCS" = "$EXPECTED_DOCS"

# 9) 금지 문서 미변경
! echo "$CHANGED_DOCS" | grep -qF 'docs/data-schema.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/user-intervention.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/flow.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/prd.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/mission.md'

# 10) 미래 약속 문구 미포함
! grep -F '곧 지원' docs/adr.md
! grep -F '로드맵' docs/adr.md
! grep -F '조만간' docs/adr.md
! grep -F '곧 지원' docs/spec.md
! grep -F '조만간' docs/spec.md
! grep -F '곧 지원' docs/testing.md
! grep -F '곧 지원' docs/code-architecture.md
```

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `tasks/6-coaching-generator/index.json` 의 phase 0 status 를 `"completed"` 로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"` 로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

## 주의사항

- **ADR-006 원문 2줄(결정 + 이유) 은 불변**: Update 블록은 "이유" 줄 뒤 빈 줄 후 삽입. ADR-006 을 ADR-019 로 승격/복제하지 마라.
- **§2.7 과 §2.6 의 렌더링 충돌 주의**: 기존 §2.6 마지막 bullet(`0rep 세션`) 뒤 빈 줄 1개 확보한 뒤 §2.7 삽입. 연속된 h3 끼리 빈 줄 누락하면 markdown 렌더러에 따라 병합될 수 있다.
- **스키마 변경 금지**: `docs/data-schema.md` 는 `UserProfile` / `WorkoutSession` 그대로. `UserProfile.onboardingCompleted` 구형 기술도 건드리지 마라 (별건 티켓 scope). `@AppStorage` 정정은 `docs/spec.md §2.7` 내부 언급으로만 반영.
- **docs-diff.md 는 직접 쓰지 마라**: Phase 0 완료 후 runner(`scripts/gen-docs-diff.py`) 가 자동 생성. `tasks/6-coaching-generator/docs-diff.md` 파일을 수동으로 만들지 마라.
- **기존 테스트를 깨뜨리지 마라**: docs 만 변경이라 빌드/테스트 영향 없음. 다만 `Mofit/` 파일을 실수로 건드리면 AC 7 실패.
- **git status 클린 상태 시작**: dirty 면 error 기록 후 중단.
- **ADR 번호 유지**: ADR-006 은 기존 번호 그대로. ADR-018 의 "(task 4-diagnostic-hint)" update 포맷을 참조하되, ADR-006 자체에는 update 한 번도 없었으므로 이번이 최초 Update 블록.
- **`docs/code-architecture.md` 의 디렉토리 tree 수정 시 들여쓰기/파이프 문자 정확성**: `│   │   ├──` / `│   │   └──` 한글 들여쓰기/공백 수 변경 금지. 기존 tree 의 ASCII art 규칙 그대로 유지.
- **`docs/testing.md` 상단 3줄 원칙 불변**: 새 섹션은 파일 **끝** 에 추가. 기존 원칙 사이에 끼워 넣지 마라.
