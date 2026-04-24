# Phase 0: docs

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다.

```bash
git status --porcelain -- docs/ Mofit/ project.yml
```

출력되는 파일이 있으면 이전 작업의 잔여 변경이 남아 있다는 뜻이다. 진행하지 말고 `tasks/2-tap-fallback/index.json`의 phase 0 status를 `"error"`로 변경, `error_message` 필드에 `dirty working tree (docs/ | Mofit/ | project.yml)`로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/mission.md`
- `docs/prd.md`
- `docs/spec.md` (특히 §2.1 트래킹 상태머신 — 이번 phase 수정 대상)
- `docs/adr.md` (특히 ADR-001 Apple Vision, ADR-004 15fps 샘플링, ADR-009 MVP 제외 목록, ADR-016 스쿼트 외 운동 UI 처리)
- `docs/code-architecture.md` (특히 "트래킹 상태 머신" + "카메라 파이프라인" 섹션)
- `docs/flow.md`
- `docs/testing.md`
- `docs/user-intervention.md`
- `iterations/3-20260424_162818/requirement.md` (이번 iteration 원문 — 수정 금지)

## 작업 내용

이번 iteration의 상태머신 변경(손바닥 1초 OR 화면 탭으로 트리거 다중화)을 문서 레이어에 먼저 반영한다. **실코드는 Phase 1에서 수정한다.** 본 phase에서는 `docs/`만 건드리고, 다른 디렉토리는 절대 변경하지 않는다.

### 1. `docs/spec.md` — §2.1 트래킹 상태머신 (현재 L46-55)

**기존** (code fence 안의 다이어그램 부분):

```
idle
  ── 손바닥 1초 ──▶ countdown(5s)
                      └─ 완료 ──▶ tracking
tracking
  ── 손바닥 1초 ──▶ setComplete
                      └─ 표시 후 ──▶ countdown(5s) ──▶ tracking (다음 세트)
any
  ── stop 버튼 ──▶ saveRecord ──▶ home (폭죽 연출)
```

**신규** (아래 내용으로 정확히 교체):

```
idle
  ── 손바닥 1초 OR 화면 탭 ──▶ countdown(5s)
                      └─ 완료 ──▶ tracking
tracking
  ── 손바닥 1초 OR 화면 탭(rep > 0) ──▶ setComplete
                      └─ 표시 후 ──▶ countdown(5s) ──▶ tracking (다음 세트)
any
  ── stop 버튼 ──▶ saveRecord ──▶ home (폭죽 연출)
```

변경점:
- `idle` 전이: `손바닥 1초` → `손바닥 1초 OR 화면 탭`
- `tracking` 전이: `손바닥 1초` → `손바닥 1초 OR 화면 탭(rep > 0)` (rep > 0 조건은 CTO 조건부 #2 반영)
- `any`/`stop 버튼` 줄, 그 밖의 공백, 줄바꿈, 앞뒤 단락은 단 한 글자도 바꾸지 마라.

### 2. ADR 신규 작성 여부

**ADR 신규 작성 금지.** 이번 변경(SwiftUI onTapGesture 2곳 + 서브카피 리터럴 + ViewModel rename)은 "번복 비용 거의 0"인 결정이라 ADR 표면적에 올리지 않는다. `docs/adr.md`는 건드리지 마라.

### 3. 무변경 강제 — 전체 목록

- `docs/adr.md` — ADR 신규 작성 금지 (CTO 결재).
- `docs/prd.md` — 랜딩/미팅 용도 문서. 출시 전 카피 추가 금지.
- `docs/code-architecture.md` — "트래킹 상태 머신" 섹션이 존재하지만 이번 phase에서 건드리지 않는다. 코드 상태머신 변경분은 Phase 1 구현 이후 차후 task에서 동기화한다. (이번 phase는 spec.md 한 파일로 한정.)
- `docs/flow.md`, `docs/mission.md`, `docs/testing.md`, `docs/data-schema.md`, `docs/user-intervention.md` — 무변경.
- `iterations/3-20260424_162818/requirement.md` — iteration 산출물. 수정 금지.
- `Mofit/**`, `project.yml`, `scripts/`, `server/`, `tasks/0-exercise-coming-soon/**`, `tasks/1-coaching-samples/**` — Phase 0에서 코드/설정/타 task 변경 절대 금지.
- 신규 docs 파일 생성 금지.

### 4. 문구 일관성 (Phase 1 구현과 1:1 일치)

Phase 1이 Swift 리터럴로 박을 문구는 아래와 같다. 본 phase에서 작성하는 spec.md의 해당 표현이 Phase 1 구현과 **의미 동등**해야 한다 (spec.md `화면 탭` 표현과 Swift `화면을 탭` 동사 활용 허용).

| 항목                          | Phase 1 Swift 리터럴                                    |
| ----------------------------- | ------------------------------------------------------ |
| idle 서브카피                 | `손바닥을 보여주거나 화면을 탭하세요`                   |
| tracking caption              | `끝낼 땐 화면을 탭하거나 손바닥을 보여주세요`            |
| ViewModel public 핸들러       | `handleScreenTap()`                                    |
| ViewModel rename 결과          | `triggerSetAction()` (기존 `triggerPalmAction()`을 교체) |
| tracking 탭 가드              | `currentReps > 0`                                      |

(Phase 1은 이 표를 원본으로 삼아 Swift 리터럴/시그니처를 작성한다. 본 phase는 spec.md 다이어그램 2줄 갱신만.)

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0이어야 한다.

```bash
# 1) spec.md에 신규 표현 존재 (idle 전이 + tracking 전이)
grep -F "손바닥 1초 OR 화면 탭 ──▶ countdown(5s)" docs/spec.md
grep -F "손바닥 1초 OR 화면 탭(rep > 0) ──▶ setComplete" docs/spec.md

# 2) 기존 표현 제거 확인 — "손바닥 1초 ──▶ countdown(5s)" 같은 OR 없는 라인이 더 이상 존재하지 않음
! grep -E "^  ── 손바닥 1초 ──▶ countdown\\(5s\\)" docs/spec.md
! grep -E "^  ── 손바닥 1초 ──▶ setComplete" docs/spec.md

# 3) 변경 범위 docs/spec.md 단일 파일
test "$(git diff --name-only HEAD -- docs/)" = "docs/spec.md"

# 4) docs 외부 미변경
test -z "$(git diff --name-only HEAD -- Mofit/ project.yml scripts/ server/ iterations/ tasks/0-exercise-coming-soon/ tasks/1-coaching-samples/)"

# 5) ADR 미변경
git diff --quiet HEAD -- docs/adr.md

# 6) spec.md 다른 표제 보존 — §2.1 제목 라인 정확 1회
test "$(grep -c '^### 2.1 트래킹 상태머신' docs/spec.md)" -eq 1

# 7) AuthGateView 라인 등 task 1의 변경 결과가 훼손되지 않음
grep -F "AI 코칭 샘플 피드백 카드 2장(운동 전/후) 상단 노출." docs/spec.md
```

(테스트 target 없음. 이 phase는 docs only이므로 xcodebuild는 Phase 1에서만 수행.)

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `/tasks/2-tap-fallback/index.json`의 phase 0 status를 `"completed"`로 변경하라.
수정 3회 이상 시도해도 실패하면 status를 `"error"`로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

## 주의사항

- **ADR 신규 작성 금지.** CTO가 "번복 비용 0인 UI 제스처 추가는 ADR에 올리지 않는다"고 결재. `docs/adr.md` 절대 수정 금지.
- **spec.md 수정 범위는 §2.1 상태머신 다이어그램 2줄로 한정.** 다른 섹션(§2.2~§2.4, §3 이하)은 공백·줄바꿈까지 그대로 두어라.
- **다이어그램 체인의 "└─ 완료 ──▶ tracking" / "└─ 표시 후 ──▶ countdown(5s) ──▶ tracking (다음 세트)" / "any / ── stop 버튼 ──▶ saveRecord ──▶ home (폭죽 연출)" 는 손대지 마라.**
- **requirement.md 읽기 전용.** iteration 디렉토리 하위 수정 금지.
- **Mofit/ 디렉토리 및 project.yml 수정 금지.** 이 phase는 docs-only 변경.
- **새 docs 파일 생성 금지.** `docs/` 내 기존 `spec.md` 1개만 편집.
- **user-intervention.md 항목 추가 금지.** 본 iteration에서 새로 발생한 인간 개입 지점 없음 (기존 항목: App Store 배포 / 서버 재배포 / 시뮬·실기기 QA).
- **tasks/0-exercise-coming-soon/, tasks/1-coaching-samples/ 건드리지 마라.** 완료된 이전 task.
- **Phase 1 리터럴 표와 spec.md 표현이 1:1이 아니어도 좋다.** spec.md는 축약(`화면 탭`), Swift는 완전 동사(`화면을 탭하세요`)로 적는다. 일치시키려 Swift 리터럴 미리 박지 마라 — 본 phase는 docs only.
