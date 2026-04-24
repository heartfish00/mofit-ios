# Phase 0: docs

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다.

```bash
git status --porcelain -- docs/ Mofit/ project.yml README.md
```

출력되는 파일이 있으면 이전 작업의 잔여 변경이 남아 있다는 뜻이다. 진행하지 말고 `tasks/3-squat-only-pivot/index.json`의 phase 0 status를 `"error"`로 변경, `error_message` 필드에 `dirty working tree (docs/ | Mofit/ | project.yml | README.md)`로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/mission.md` (§"의도적 제외 범위 (MVP)" — 이번 phase 수정 대상)
- `docs/prd.md` (§기능범위 > 홈탭 / 운동 선택 — 이번 phase 수정 대상)
- `docs/spec.md` (§1.3 화면 목록 — ExercisePickerView 행 삭제 대상)
- `docs/flow.md` (§2 운동 흐름 — 바텀시트 줄 제거 대상)
- `docs/code-architecture.md` (§디렉토리 구조 Views/Home 섹션 — ExercisePickerView.swift 참조 제거 대상)
- `docs/adr.md` (ADR-008, ADR-016 SUPERSEDED 처리 + ADR-017 신규)
- `docs/testing.md`
- `docs/user-intervention.md`
- `README.md` (대외 포지셔닝 카피 — 이번 phase 수정 대상)
- `iterations/4-20260424_193445/requirement.md` (이번 iteration 원문 — 수정 금지)
- `tasks/2-tap-fallback/phase0.md` / `tasks/2-tap-fallback/phase1.md` (바로 직전 task 스타일 참고용 — 수정 금지)

## 작업 내용

이번 iteration의 포지셔닝 변경(홈트→스쿼트 전용)을 **문서 레이어에 먼저** 반영한다. **실코드는 Phase 1에서 수정한다.** 본 phase에서는 `docs/` + `README.md` 만 건드리고, 다른 디렉토리는 절대 변경하지 않는다.

변경 대상 파일은 총 7개: `docs/mission.md`, `docs/prd.md`, `docs/spec.md`, `docs/flow.md`, `docs/code-architecture.md`, `docs/adr.md`, `README.md`.

### 1. `docs/mission.md` — §"의도적 제외 범위 (MVP)"

해당 파일의 **마지막 bullet (현재 기준 L45)**:

**기존**:

```
- 스쿼트 외 운동의 별도 판정 로직 (UI는 노출, 내부는 스쿼트 통일)
```

**신규** (정확히 아래 한 줄로 교체):

```
- 스쿼트 외 운동 (UI에도 노출하지 않음, ADR-017)
```

- 다른 bullet / 제목 / 빈 줄은 단 한 글자도 바꾸지 마라.
- 괄호 안 `ADR-017` 문자열은 반드시 포함 (AC grep 대상).

### 2. `docs/prd.md` — §기능범위 > 홈탭 / 운동 선택

#### 2-a) §홈탭

**기존** (현재 L26~31 영역, 5개 bullet):

```
### 홈탭
- "모핏" 타이틀 (좌상단), 프로필 편집 버튼 (우상단)
- 운동 종류 선택 영역 (탭 → 바텀시트 그리드)
- 운동 시작 버튼 (형광초록, 크게)
- 오늘의 기록 요약 (세트, rep, 시간). 기록 없으면 "첫 운동을 시작해보세요!"
- 운동 종료 후 복귀 시 폭죽 효과
```

**신규** (정확히 아래 4 bullet으로 교체):

```
### 홈탭
- "모핏" 타이틀 (좌상단), 프로필 편집 버튼 (우상단)
- "스쿼트 시작" 버튼 (형광초록, 크게) — 탭 시 바로 트래킹 화면 진입. 운동 종류 선택 UI 없음 (ADR-017)
- 오늘의 기록 요약 (세트, 스쿼트, 시간). 기록 없으면 "첫 운동을 시작해보세요!"
- 운동 종료 후 복귀 시 폭죽 효과
```

#### 2-b) §운동 선택 (바텀시트) 섹션 전체 삭제

현재 L33~35 전후의 아래 섹션을 **통째로 제거** (제목 포함):

```
### 운동 선택 (바텀시트)
- 2열 그리드: 스쿼트 / 푸쉬업 / 싯업 (실코드 기준)
- MVP에서는 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4로 비활성화 톤, tap 시 토스트 "현재는 스쿼트만 지원합니다"만 표시하고 트래킹 진입 차단. (ADR-016)
```

- 이 섹션과 섹션 앞뒤 빈 줄을 삭제해 `### 홈탭` 블록 다음에 바로 `### 트래킹 화면` 이 오도록 한다.
- §트래킹 화면 이후 섹션들(프로필 수정 / 기록탭 / AI 코칭탭 / 디자인 / 인증 및 데이터 저장 / MVP 제외 사항) 은 **한 글자도 바꾸지 마라.**

### 3. `docs/spec.md` — §1.3 화면 목록

현재 §1.3 (L28~39) 에서 아래 라인:

**기존**:

```
- `ExercisePickerView` — 바텀시트 2열 그리드 (스쿼트/푸쉬업/싯업). 스쿼트만 active, 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4로 비활성화 톤, tap 시 토스트 "현재는 스쿼트만 지원합니다"만 표시. (ADR-016)
```

**삭제**. 그리고 바로 앞 라인:

**기존**:

```
- `HomeView` — 오늘 요약 + 운동 시작
```

**신규**:

```
- `HomeView` — 오늘 요약 + "스쿼트 시작" 버튼 (운동 종류 선택 UI 없음, ADR-017)
```

- §1.3 의 다른 bullet (`OnboardingView`, `TrackingView`, `RecordsView`, `CoachingView`, `ProfileEditView`, `AuthGateView`, `SignupView`/`LoginView`) 은 모두 유지. 순서·공백·줄바꿈 불변.
- §1.1, §1.2, §2 이하 모든 섹션은 이번 phase 에서 수정 금지 (특히 §2.1 트래킹 상태머신은 task 2 산출물이라 보존).

### 4. `docs/flow.md` — §2 운동 흐름

현재 §2 (L17~37) 의 code-block 맨 위 3줄:

**기존**:

```
홈탭
  → 운동 종류 탭 → 바텀시트 그리드 → 선택 → 시트 닫힘
  → "운동 시작" 탭
```

**신규** (정확히 아래 2줄로 교체):

```
홈탭
  → "스쿼트 시작" 탭
```

- `→ (최초 1회) 카메라 권한 요청` 이하 줄은 전부 유지. 트래킹 상태 머신 블록도 불변.
- §1, §3, §4, §5, §6, §7, §8, §9, §10 은 수정 금지.

### 5. `docs/code-architecture.md` — §디렉토리 구조

현재 §디렉토리 구조 (L6~54) 의 `Views/Home/` 항목 2줄:

**기존**:

```
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── ExercisePickerView.swift
```

**신규** (정확히 아래 2줄로 교체):

```
│   ├── Home/
│   │   └── HomeView.swift
```

- `Views/Tracking/`, `Views/Records/`, `Views/Coaching/`, `Views/Profile/`, `Views/Onboarding/` 블록은 불변.
- `## 카메라 파이프라인` 이하 섹션은 전부 불변.

### 6. `docs/adr.md` — ADR-008, ADR-016 SUPERSEDED + ADR-017 신규

#### 6-a) ADR-008 에 SUPERSEDED 머리말 추가

**기존** (현재 L41~43):

```
### ADR-008: 운동 선택 UI는 있되 내부 처리는 스쿼트 통일
**결정**: 4종 운동 선택 UI 제공, 내부적으로 전부 스쿼트로 처리.
**이유**: UI 완성도 + 확장 가능성 확보. 사용자 입장에서 앱이 "하나만 되는 앱"으로 보이지 않게. 실제 운동별 판정 로직은 검증 후 점진적 추가.
```

**신규** (제목 바로 아래에 `**SUPERSEDED by ADR-017**` 라인 삽입):

```
### ADR-008: 운동 선택 UI는 있되 내부 처리는 스쿼트 통일
**SUPERSEDED by ADR-017** — 스쿼트 전용 포지셔닝으로 전환. 운동 선택 UI 자체가 제거됨.
**결정**: 4종 운동 선택 UI 제공, 내부적으로 전부 스쿼트로 처리.
**이유**: UI 완성도 + 확장 가능성 확보. 사용자 입장에서 앱이 "하나만 되는 앱"으로 보이지 않게. 실제 운동별 판정 로직은 검증 후 점진적 추가.
```

#### 6-b) ADR-016 에 SUPERSEDED 머리말 추가

**기존** (현재 L81~84):

```
### ADR-016: 스쿼트 외 운동은 "준비중" UI로 공개 (ADR-008 보완)
**결정**: ExercisePicker에서 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4의 비활성화 톤으로 표시. tap 자체는 차단하지 않되, selected 전환/화면 dismiss 대신 토스트 "현재는 스쿼트만 지원합니다"만 1.5초 노출하고 트래킹 진입은 차단.
**이유**: ADR-008("UI는 있되 내부 전부 스쿼트 통일")은 3일 체험 페르소나가 푸쉬업을 한 번만 눌러봐도 기대 불일치가 드러나 즉시 삭제 트리거가 됨 (시뮬 run_id: home-workout-newbie-20s_20260424_153242). 기능 다양성 과시보다 신뢰도 우선.
**트레이드오프**: 운동별 판정 로직이 추가될 때까지 선택지 다양성 축소. 셀 tap 자체는 남겨둬 향후 재활성화 시 회귀 테스트 누락 리스크를 줄임. 토스트 카피에는 "곧 지원됩니다" 같은 미래 약속 문구 금지.
```

**신규** (제목 바로 아래에 `**SUPERSEDED by ADR-017**` 라인 삽입):

```
### ADR-016: 스쿼트 외 운동은 "준비중" UI로 공개 (ADR-008 보완)
**SUPERSEDED by ADR-017** — "준비중" UI 자체가 제거됨. 스쿼트 전용 포지셔닝으로 전환.
**결정**: ExercisePicker에서 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4의 비활성화 톤으로 표시. tap 자체는 차단하지 않되, selected 전환/화면 dismiss 대신 토스트 "현재는 스쿼트만 지원합니다"만 1.5초 노출하고 트래킹 진입은 차단.
**이유**: ADR-008("UI는 있되 내부 전부 스쿼트 통일")은 3일 체험 페르소나가 푸쉬업을 한 번만 눌러봐도 기대 불일치가 드러나 즉시 삭제 트리거가 됨 (시뮬 run_id: home-workout-newbie-20s_20260424_153242). 기능 다양성 과시보다 신뢰도 우선.
**트레이드오프**: 운동별 판정 로직이 추가될 때까지 선택지 다양성 축소. 셀 tap 자체는 남겨둬 향후 재활성화 시 회귀 테스트 누락 리스크를 줄임. 토스트 카피에는 "곧 지원됩니다" 같은 미래 약속 문구 금지.
```

#### 6-c) ADR-017 신규 추가

ADR-016 끝 다음 줄(빈 줄 포함)에 아래 블록을 **파일 맨 끝에 append**. ADR-017이 `docs/adr.md` 의 최종 ADR 이 되도록 한다.

```
### ADR-017: 스쿼트 전용 포지셔닝 확정 (ADR-008, ADR-016 대체)
**결정**: ExercisePickerView 파일 삭제 + HomeView의 운동 종류 선택 드롭다운 제거. "스쿼트 시작" 고정 CTA 로 전환. 랜딩/README/docs 카피에서 "홈트/운동 종류" 언어를 "스쿼트"로 정돈. 미래 약속 문구(곧 지원됩니다, 로드맵 등) 금지.
**이유**: iter 4 설득력 검토(run_id: home-workout-newbie-20s_20260424_193756)에서 "홈트 기대 설치 → 3일 안에 스쿼트 전용임 인지 → 무료 스쿼트 카운터로 전환" 이탈 경로가 keyman 최종 판정 실패의 독립적 reject 사유. "준비중" UI 를 남겨두는 것만으로도 `personality_notes`("3일 써보고 아니면 삭제") + `switching_cost: low` 경쟁재 조건에서 기대 불일치가 드러남. 포지셔닝 자체를 스쿼트 전용으로 좁혀 기대-실제 갭을 제거.
**트레이드오프**: 푸쉬업/싯업 확장 시 운동 종류 선택 UI/상태를 복구해야 함. 단, `TrackingViewModel.exerciseType` 분기 + `PushUpCounter.swift`/`SitUpCounter.swift` 내부 판정 자산은 보존(CTO 조건부 #1)하여 재활성화 비용 최소화. 이번 삭제는 View 레이어 한정.
**범위**: `Mofit/Views/Home/ExercisePickerView.swift` 파일 삭제, `Mofit/Views/Home/HomeView.swift` 에서 `exerciseSelector`·`showExercisePicker`·`selectedExerciseName` 상태 제거. `TrackingView(exerciseType: "squat", ...)` 호출로 하드코딩. ADR-008/ADR-016 은 SUPERSEDED 표기 유지(역사 보존).
```

- ADR-017 텍스트 내 `run_id`, `keyman`, `personality_notes`, `switching_cost` 는 backtick/인용부호 그대로 유지.
- "곧 지원됩니다" 같은 미래 약속 문구 금지(ADR-017 본문 자체가 그 원칙을 선언한다).
- ADR-001~ADR-016 의 기존 내용은 6-a/6-b 에서 지정한 변경 외에는 **한 글자도 바꾸지 마라.**

### 7. `README.md` — 대외 포지셔닝 카피

#### 7-a) 한 줄 태그라인 (현재 L3)

**기존**:

```
AI 기반 실시간 운동 자세 분석 및 코칭 iOS 앱
```

**신규**:

```
iPhone 카메라만으로 스쿼트를 자동으로 세는 iOS 앱
```

#### 7-b) §소개 (현재 L9)

**기존**:

```
Mofit은 iPhone 카메라와 Apple Vision 프레임워크를 활용하여 사용자의 운동 자세를 실시간으로 분석하고, Claude AI를 통해 개인 맞춤형 코칭 피드백을 제공하는 피트니스 앱입니다.
```

**신규**:

```
Mofit은 iPhone 카메라와 Apple Vision 프레임워크를 활용하여 스쿼트 자세를 실시간으로 분석하고, 횟수를 자동으로 세는 앱입니다. Claude AI 기반 개인 맞춤 피드백은 로그인 시 부가 가치로 제공됩니다.
```

#### 7-c) §주요 기능 (현재 L11~18)

**기존** (6 bullet):

```
## 주요 기능

- **실시간 자세 분석** — Vision 프레임워크로 15개 이상의 관절을 추적하여 운동 폼을 실시간 분석
- **자동 레프 카운팅** — 무릎 각도 기반으로 스쿼트 횟수를 자동 측정
- **제스처 컨트롤** — 손바닥 펼침 인식으로 세트 완료 등 핸즈프리 조작
- **AI 코칭** — Claude AI가 운동 이력과 사용자 프로필을 기반으로 맞춤형 피드백 제공
- **코치 스타일 선택** — 강한 동기부여 / 따뜻한 격려 / 데이터 분석형 중 선호 스타일 선택
- **운동 기록 관리** — 날짜별 운동 세션 기록 조회
```

**신규** (정확히 아래 6 bullet 으로 교체):

```
## 주요 기능

- **실시간 스쿼트 자세 분석** — Vision 프레임워크로 hip–knee–ankle 각도를 추적해 폼을 실시간 분석
- **자동 rep 카운팅** — 무릎 각도 기반으로 스쿼트 횟수를 자동 측정 (서있음>160° → 앉음<100° → 서있음 = 1 rep)
- **핸즈프리 트리거** — 손바닥 펼침 1초 또는 화면 탭으로 스쿼트 세트 시작/종료
- **AI 코칭** — Claude AI 가 운동 이력과 사용자 프로필을 기반으로 맞춤 피드백 제공 (로그인 시)
- **코치 스타일 선택** — 강한 동기부여 / 따뜻한 격려 / 데이터 분석형 중 선호 스타일 선택
- **운동 기록 관리** — 날짜별 스쿼트 세션 기록 조회
```

#### 7-d) §프로젝트 구조 (현재 L59~80)

`Views/` 블록 안에서 현재:

```
└── Views/          # SwiftUI 화면
    ├── Coaching/       # AI 코칭
    ├── Home/           # 홈 (운동 시작, 오늘의 요약)
```

를 아래와 같이 변경:

```
└── Views/          # SwiftUI 화면
    ├── Coaching/       # AI 코칭
    ├── Home/           # 홈 (스쿼트 시작, 오늘의 요약)
```

- `Onboarding/`, `Profile/`, `Records/`, `Tracking/` 라인은 불변.

#### 7-e) README 그 외 섹션 불변

`§소개` 윗단 `Made by VibeMatfia` 라인, `§기술 스택` 표, `§요구 사항`, `§설치 및 실행` 코드블록, `§자율 주행 하네스` 섹션, `§라이선스` 는 한 글자도 바꾸지 마라. "푸쉬업·싯업 로드맵" 같은 미래 약속 문구를 **어떤 형태로도 추가하지 마라** (CTO 조건부 #3).

### 8. 무변경 강제 — 전체 목록

- `docs/data-schema.md` — 서버 스키마 문서. 이번 phase 에서 건드리지 마라.
- `docs/testing.md`, `docs/user-intervention.md` — 불변.
- `iterations/4-20260424_193445/**` — iteration 산출물. 읽기 전용.
- `persuasion-data/**` — 설득력 검토 산출물. 읽기 전용.
- `Mofit/**`, `project.yml`, `scripts/**`, `server/**`, `tasks/0-exercise-coming-soon/**`, `tasks/1-coaching-samples/**`, `tasks/2-tap-fallback/**` — Phase 0 에서 코드/설정/타 task 변경 절대 금지.
- 신규 docs 파일 생성 금지. README 외 새 마크다운 생성 금지.

### 9. user-intervention.md

이번 iteration 에서 신규 인간 개입 지점은 없다. `docs/user-intervention.md` 는 수정하지 마라.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0이어야 한다. 각 커맨드는 문자열이 정확히 일치하지 않으면 실패한다.

```bash
# 1) mission.md — 신규 bullet 존재 + 구 표현 제거
grep -F "스쿼트 외 운동 (UI에도 노출하지 않음, ADR-017)" docs/mission.md
! grep -F "(UI는 노출, 내부는 스쿼트 통일)" docs/mission.md

# 2) prd.md — 홈탭 신 bullet + 운동 선택 섹션 제거
grep -F "\"스쿼트 시작\" 버튼 (형광초록, 크게)" docs/prd.md
grep -F "오늘의 기록 요약 (세트, 스쿼트, 시간)" docs/prd.md
! grep -F "운동 종류 선택 영역 (탭 → 바텀시트 그리드)" docs/prd.md
! grep -F "### 운동 선택 (바텀시트)" docs/prd.md
! grep -F "준비중" docs/prd.md

# 3) spec.md — HomeView 신 bullet + ExercisePickerView 제거
grep -F '`HomeView` — 오늘 요약 + "스쿼트 시작" 버튼' docs/spec.md
! grep -F "`ExercisePickerView`" docs/spec.md

# 4) flow.md — 바텀시트 줄 제거 + 스쿼트 시작 탭 표현 존재
grep -F '→ "스쿼트 시작" 탭' docs/flow.md
! grep -F "운동 종류 탭 → 바텀시트 그리드" docs/flow.md

# 5) code-architecture.md — ExercisePickerView.swift 제거
! grep -F "ExercisePickerView.swift" docs/code-architecture.md

# 6) adr.md — ADR-008/016 SUPERSEDED + ADR-017 본문 + 범위 선언
grep -F "### ADR-008: 운동 선택 UI는 있되 내부 처리는 스쿼트 통일" docs/adr.md
grep -F "### ADR-016: 스쿼트 외 운동은 \"준비중\" UI로 공개 (ADR-008 보완)" docs/adr.md
grep -F "### ADR-017: 스쿼트 전용 포지셔닝 확정 (ADR-008, ADR-016 대체)" docs/adr.md
test "$(grep -cF '**SUPERSEDED by ADR-017**' docs/adr.md)" -eq 2
grep -F "TrackingViewModel.exerciseType" docs/adr.md

# 7) README.md — 신 태그라인 + 구 태그라인 제거 + Home 설명 갱신
grep -F "iPhone 카메라만으로 스쿼트를 자동으로 세는 iOS 앱" README.md
! grep -F "AI 기반 실시간 운동 자세 분석 및 코칭 iOS 앱" README.md
grep -F "실시간 스쿼트 자세 분석" README.md
grep -F "핸즈프리 트리거" README.md
grep -F "홈 (스쿼트 시작, 오늘의 요약)" README.md

# 8) 미래 약속 문구 금지 (CTO 조건부 #3) — README 내 금지어 없음
! grep -F "곧 지원" README.md
! grep -F "로드맵" README.md
! grep -F "출시 예정" README.md

# 9) 변경 범위 — docs/ 하위 정확히 6개 파일 + README.md
CHANGED=$(git diff --name-only HEAD -- docs/ README.md | sort)
EXPECTED=$(printf 'README.md\ndocs/adr.md\ndocs/code-architecture.md\ndocs/flow.md\ndocs/mission.md\ndocs/prd.md\ndocs/spec.md\n' | sort)
test "$CHANGED" = "$EXPECTED"

# 10) docs/ + README.md 외부 미변경
test -z "$(git diff --name-only HEAD -- Mofit/ project.yml scripts/ server/ iterations/ persuasion-data/ tasks/0-exercise-coming-soon/ tasks/1-coaching-samples/ tasks/2-tap-fallback/)"

# 11) user-intervention.md, testing.md, data-schema.md 미변경
git diff --quiet HEAD -- docs/user-intervention.md docs/testing.md docs/data-schema.md
```

(테스트 target 없음. 이 phase 는 docs only 이므로 xcodebuild 는 Phase 1 에서만 수행.)

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/3-squat-only-pivot/index.json` 의 phase 0 status 를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"`로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

## 주의사항

- **수정 대상은 정확히 7개 파일** (`docs/mission.md`, `docs/prd.md`, `docs/spec.md`, `docs/flow.md`, `docs/code-architecture.md`, `docs/adr.md`, `README.md`). 이 외 파일 변경 금지. AC #9 가 엄격히 검증한다.
- **ADR-008 / ADR-016 본문은 SUPERSEDED 한 줄만 추가**. 기존 "결정/이유/트레이드오프" 문장을 수정·삭제하지 마라. 역사 보존이 원칙.
- **미래 약속 문구 금지** (CTO 조건부 #3). README / docs 어디에도 "곧 지원", "로드맵", "출시 예정", "차기 버전", "준비중" 같은 표현을 남기지 마라. ADR-017 본문 안에서도 자제.
- **Mofit/ 디렉토리 및 project.yml 수정 금지.** 실코드 변경은 Phase 1.
- **xcodeproj 재생성 금지.** `xcodegen generate` 는 Phase 1 에서 실행.
- **iteration/persuasion-data 디렉토리 읽기 전용.** 수정하면 AC #10 에서 실패.
- **task 0/1/2 디렉토리 건드리지 마라.** 완료된 이전 task.
- **신규 docs 파일 생성 금지.** 기존 파일만 편집.
- **user-intervention.md 항목 추가 금지.** 이번 iteration 에서 새로 발생한 인간 개입 지점 없음 (기존 항목: Secrets / App Store / Supabase).
- **testing.md, data-schema.md 수정 금지.** 이번 티켓과 무관.
- **ADR-017 범위 선언에 "CTO 조건부 #1" 반드시 인용**: `TrackingViewModel.exerciseType` 분기 + `PushUpCounter.swift`/`SitUpCounter.swift` 파일 보존이 설계 의도. AC #6 가 `TrackingViewModel.exerciseType` 문자열 존재를 검사한다.
- **AC grep 은 정확 문자열 기준.** 공백·따옴표·괄호 유니코드 변형 금지. 특히 큰따옴표(`"`) vs 한글 따옴표(`"` `"`) 혼동 주의.
