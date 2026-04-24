# Phase 0: docs

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다.

```bash
git status --porcelain -- docs/ Mofit/ project.yml README.md tasks/5-rep-autosave/
```

출력되는 파일이 있으면 working tree 가 더럽다. 진행하지 말고 `tasks/5-rep-autosave/index.json` 의 phase 0 status 를 `"error"`로 변경, `error_message` 에 `dirty working tree before phase 0` 로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/prd.md` — 가치제안 §5 리스크 고지(6번: 크래시/데이터 복구 없음 항목이 이번 task 대상)
- `docs/spec.md` — §2 상태머신, §3 데이터 모델 (WorkoutSession 필드), §5 네트워킹 분기 테이블
- `docs/adr.md` — **ADR-009** (MVP 의도적 제외 목록 — 이번 task 가 delta 업데이트 대상), ADR-013(로그인/비로그인 분기), ADR-014(네트워크 실패 시 로컬 임시 저장 없음), ADR-017(스쿼트 전용 포지셔닝), ADR-018(diagnostic hint — 가장 최근 전례)
- `docs/code-architecture.md` — ViewModels/Services 책무
- `docs/testing.md` — 3줄 원칙. 이 task 에서도 `MofitTests` 타겟 신설 금지 (task 0~4 전례)
- `docs/user-intervention.md` — 기존 §트래킹 진단 힌트 실기기 QA (ADR-018) 항목의 포맷을 본떠 새 절차 추가
- `iterations/6-20260424_214957/requirement.md` — iteration 원문 (§채택된 요구사항 / §구현 스케치 / §CTO 승인 조건부 5항 — 특히 조건 1(c), 2, 3, 5 가 이번 task 설계의 원전)

그리고 이전 task 전례(Phase 0 docs 업데이트 스타일 참고용):

- `tasks/4-diagnostic-hint/phase0.md` — 가장 최근 task 의 Phase 0. docs delta 작성 톤/형식 참조.
- `tasks/4-diagnostic-hint/docs-diff.md` — Phase 0 완료 후 runner 가 자동 생성한 diff. 이번 phase 도 동일 방식.

이 Phase 는 **코드 변경 없음**. `docs/` 4개 파일만 수정한다. `Mofit/` · `project.yml` · `README.md` · `server/` 는 터치 금지.

## 작업 내용

### 대상 파일 (정확히 4개)

1. `docs/adr.md` — ADR-009 에 Update 블록 1개 추가 (ADR 신설 금지).
2. `docs/spec.md` — §2 에 2.6 신규 서브섹션 추가 + §3.1 한 줄 주석 + §5 분기 테이블 "운동 완료 저장" 행 보강.
3. `docs/user-intervention.md` — 신규 §항목 1개 추가 (`task 5-rep-autosave` 실기기 QA).
4. `docs/code-architecture.md` — `TrackingViewModel` 책무 설명에 "autosave(비로그인 한정)" 한 줄 추가 (해당 항목이 없으면 추가하지 말고 스킵).

### 목적

iter 6 persona(`home-workout-newbie-20s`, `risk_preference: conservative`, `personality_notes: "3일 써보고 아니면 삭제"`) 가 "2rep 하다 전화 한 통으로 세트 증발 → 즉시 이탈" 하는 경로를 막는다. pain 의 본질은 "rep 이 날아감" 이고, **이미 persist 된 상태로 기록 탭에 자연스럽게 노출만 되어도 이탈은 막힌다** (iteration §구현 스케치). 복구 UI / 이어하기 시트 / `isInProgress` 플래그는 **의도적으로 scope 외**. 이번 Phase 0 는 이 결정을 문서에 박는다.

### 구체 지시

#### 1) `docs/adr.md` — ADR-009 에 Update 블록 1개 추가

기존 ADR-009 섹션(파일 line 46~50 부근)은 **불변**. `ADR-010: 커스텀 JWT 인증` 시작 직전(기존 ADR-009 의 4줄 bullet 목록 바로 뒤, 빈 줄 뒤) 에 아래 Update 블록을 삽입한다. ADR-019 를 **신설하지 말고** ADR-009 안에 Update 블록으로만 추가하라.

```markdown
**2026-04-24 업데이트 (task 5-rep-autosave)**: "앱 종료 시 운동 데이터 복구 → 발생 빈도 낮음" 항목의 delta — rep 단위 autosave 도입(비로그인 유저 한정).
- persist 시점을 **세트 종료 시 1회 insert** → **세션(TrackingView lifecycle) 첫 세트 시작 시 1회 insert + 매 rep 증가 시 `WorkoutSession.repCounts` snapshot update + `try? modelContext.save()`** 로 이동.
- `WorkoutSession` 스키마 **불변**. `isInProgress` 플래그 추가 금지. 복구 UI / "이어하기" 시트 / HomeView 재개 버튼 / `workout_interrupted_*` analytics 이벤트 / UserDefaults 별도 저장 경로 **모두 여전히 제외**.
- 로그인 유저 경로는 불변 — 서버 `POST /sessions` 로 세트 종료 시 1회 저장 (ADR-013, ADR-014 유지).
- 트레이드오프: (a) 0rep 빈 세션이 SwiftData 에 기록될 수 있음 → `RecordsView` 에서 `$0.totalReps > 0` 메모리 필터로 숨김. (b) `WorkoutSession.repCounts` 의 마지막 요소는 tracking 중에는 "진행 중 세트의 임시 snapshot", `completeSet` / `stopSession` 이후에는 "확정된 세트 합계" 로 상태가 바뀐다. 독자 혼동 방지를 위해 `docs/spec.md §3.1` 에 주석 추가.
- Phase 2(이어하기 UI) 트리거 임계는 `workout_set_started` / `workout_set_completed` Mixpanel 이벤트 비율 5% 주간 초과. **단 현재 `AnalyticsService` 미도입 상태** — Phase 2 는 analytics 인프라 선행 후 별건 티켓으로 다룬다.
```

- Markdown 은 bullet 들여쓰기 일관성 유지(2 space 들여쓰기 사용 금지, 대시 `-` 만).
- 기존 ADR-009 의 4줄 bullet 과 이 Update 블록 사이에 빈 줄 1개.
- **ADR-019 를 새로 만들지 마라.** 파일에 `### ADR-019` 가 추가되면 AC 실패.

#### 2) `docs/spec.md` — §2 에 2.6 추가 + §3.1 주석 + §5 테이블 보강

##### 2-a) §2 에 2.6 서브섹션 추가

`### 2.5 트래킹 진단 힌트` 섹션의 끝(튜닝 대상 bullet 뒤, `---` 구분선 직전) 에 아래 서브섹션 통째로 삽입한다.

```markdown
### 2.6 트래킹 autosave (비로그인 한정)

비로그인 유저의 `TrackingView` 세션은 SwiftData 에 rep 단위로 자동 저장된다. pain 대응: 트래킹 중 전화/앱 전환/크래시가 발생해도 기록 탭에 현재까지의 rep 수가 남는다(ADR-009 업데이트).

- **insert 시점**: 세션 생애 첫 `startCountdown()` 호출(= `hasStartedElapsedTimer` 가 false → true 로 전이하는 순간) 에서 `WorkoutSession(startedAt: sessionStartTime, repCounts: [])` 을 1회 insert. 2번째 이후 세트 시작에서는 재 insert 없음.
- **snapshot update 시점**: Counter 의 `@Published currentReps` 가 갱신될 때마다 `session.repCounts = self.repCounts + (currentReps > 0 ? [currentReps] : [])` 로 배열 교체 + `session.endedAt = Date()` + `session.totalDuration = elapsedTime` + `try? modelContext.save()`. `lastSavedReps` no-op 가드로 동일 값 재방출 시 save 스킵.
- **completeSet 시점**: `self.repCounts.append(currentReps)` 직후 같은 session 에 `session.repCounts = self.repCounts` 로 확정 값 덮어쓰기 + save. tail 재삽입 없음.
- **stopSession 시점**: (비로그인) `session.repCounts = self.repCounts` + `endedAt` / `totalDuration` 최종 반영 + save. `currentSession = nil` 로 해제. `modelContext.insert` 는 호출하지 않음 (이미 insert 완료).
- **로그인 유저**: 전부 스킵. 기존 `POST /sessions` 서버 저장 경로 유지(ADR-013, ADR-014).
- **에러 정책**: save 실패는 `print("autosave failed: \(error)")` 만 남기고 `saveError` / alert 건드리지 않음. 트래킹 중 UI 방해 절대 금지.
- **0rep 세션**: insert 됐지만 rep 한 번도 안 들어오고 stopSession 호출된 세션은 `repCounts=[]` 로 남음. `RecordsView` 가 `$0.totalReps > 0` 필터로 숨김. SwiftData 에는 소량 남지만 UX 영향 0.
```

##### 2-b) §3.1 한 줄 주석 추가

기존 §3.1 의 `WorkoutSession` 한 줄 설명 **직후** 에 다음 한 줄 주석을 추가하라:

```markdown
  - **주의**: tracking 중에는 `repCounts` 의 마지막 요소가 "진행 중 세트의 임시 snapshot" 이며, `completeSet` / `stopSession` 이후에는 "확정된 세트 합계" 로 상태가 전환된다 (§2.6 autosave).
```

##### 2-c) §5 분기 테이블 "운동 완료 저장" 행 수정

기존 테이블의 해당 행(대략 line 183 부근):

```
| 운동 완료 저장 | `POST /sessions`                     | SwiftData 로컬 저장             |
```

를 아래로 교체:

```
| 운동 완료 저장 | `POST /sessions` (세트 종료 시 1회)    | SwiftData autosave — 세션 첫 세트 시작 insert + 매 rep snapshot save (§2.6) |
```

- 표 칼럼 정렬은 유지. 파이프 개수 변경 금지.

#### 3) `docs/user-intervention.md` — 신규 §항목 1개 추가

파일 끝의 `## 주의` 섹션 직전(기존 ADR-018 실기기 QA 항목 바로 뒤, 빈 줄 + `---` 구분선 + 빈 줄 다음 블록) 에 아래 §항목을 추가하라.

```markdown
### 트래킹 autosave 실기기 QA (task 5-rep-autosave)

- **트리거**: task `5-rep-autosave` 의 PR merge 직전 1회.
- **이유**: SwiftData 의 실제 flush 타이밍 / 앱 강제 종료 후 재실행 시 `@Query` refetch 가 단위 테스트 (in-memory ModelContainer) 로는 완벽히 재현되지 않음. iteration §CTO 승인 조건부 5 의 "실기기 QA 1회 (merge 전)" 대응.
- **절차**:
  1. **정상 경로 (a)**: 비로그인 상태로 앱 실행 → 홈 → "스쿼트 시작" → 5초 카운트다운 → 트래킹 진입 → 스쿼트 3rep 수행 → 손바닥 1초 또는 화면 탭으로 세트 종료 → 결과 화면 → 홈 복귀 → 기록 탭 진입. **오늘 날짜에 3rep 세션이 표시되어야 한다**.
  2. **크래시 복구 (b)**: 비로그인 상태로 트래킹 진입 → 스쿼트 2rep 수행(종료 트리거 **누르지 말 것**) → iOS 앱 스위처에서 Mofit 을 **위로 스와이프해 강제 종료** → 앱 재실행 → 기록 탭 진입. **오늘 날짜에 2rep 세션이 표시되어야 한다**. "이어하기" 버튼/시트는 **없는 게 정상** (scope 외).
  3. **0rep 필터 (c)**: 비로그인 상태로 트래킹 진입 → rep 한 번도 올리지 않고 닫기(x) 또는 정지 버튼 → 기록 탭 진입. **오늘 날짜에 세션 카드가 노출되지 않아야 한다** (0rep 필터).
  4. **로그인 경로 불변 (d)**: 로그인 상태로 트래킹 진입 → 스쿼트 3rep → 세트 종료 → 기록 탭 진입. **오늘 날짜에 3rep 세션이 서버에서 로드되어 표시되어야 한다** (로그인 경로가 이번 task 로 회귀하지 않았는지 smoke). 크래시 후 복구는 로그인 유저에서 기대하지 않는다(Phase 1 scope 외, ADR-013).
- **재개 신호**: 사용자가 에이전트에게 "QA OK" 라고 알려주면 merge 승인. (a)(b)(c)(d) 중 하나라도 실패 시 재현 조건을 공유하고 phase 1 재실행.
- **기록 위치**: PR 설명에 QA 수행 일시 + (a)(b)(c)(d) 각각의 pass/fail 기록.
```

- 기존 ADR-018 QA 항목 포맷과 일치. bullet 계층 동일.
- Mixpanel dashboard 뷰 생성 절차는 이번 task 에 **추가하지 마라** — `AnalyticsService` 미도입 상태라 선행 티켓 필요.

#### 4) `docs/code-architecture.md` — `TrackingViewModel` 책무에 한 줄 추가 (있을 때만)

`TrackingViewModel` 을 언급한 bullet 또는 문단이 있으면, 그 뒤에 다음 한 줄을 추가하라:

```markdown
- 비로그인 유저 한정 세션 autosave: 세션 첫 세트 시작 시 `WorkoutSession` insert + rep 마다 snapshot save (spec §2.6, ADR-009).
```

`TrackingViewModel` 관련 항목이 없다면 이 파일은 수정하지 말고 스킵하라(AC 는 `docs/` 4개 중 **최소 3개** 파일 수정으로 완화).

### 구현하지 말 것

- **ADR 신설 금지**: `### ADR-019` 추가 금지. ADR-009 Update 블록으로만.
- **`docs/testing.md` 수정 금지**: 원칙 3줄 불변. task 0~4 전례 유지.
- **`docs/data-schema.md` 수정 금지**: 스키마 불변(SwiftData `[Int]` repCounts 그대로).
- **`docs/flow.md` · `docs/mission.md` · `docs/prd.md` 수정 금지**: §5 가치제안 리스크 고지 6번은 여전히 유효 표현(복구 UI 없음). 톤 수정 불필요.
- **`README.md` · `project.yml` · `Mofit/` · `server/` 수정 금지**: 이번 Phase 는 docs 만.
- **Mixpanel / AnalyticsService 언급 추가 금지**: 미도입 상태. 유령 기능 문서화는 독자 오해.
- **"곧 지원" / "로드맵" / "차기 버전" 같은 미래 약속 문구 금지** (ADR-017 원칙 준수).

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0 이어야 한다.

```bash
# 1) ADR-009 Update 블록 존재 + ADR-019 미신설
grep -F '2026-04-24 업데이트 (task 5-rep-autosave)' docs/adr.md
grep -F 'persist 시점' docs/adr.md
grep -F '`isInProgress` 플래그 추가 금지' docs/adr.md
! grep -E '^### ADR-019' docs/adr.md

# 2) spec.md §2.6 신규 섹션
grep -F '### 2.6 트래킹 autosave' docs/spec.md
grep -F 'hasStartedElapsedTimer' docs/spec.md
grep -F 'session.repCounts = self.repCounts + (currentReps > 0 ? [currentReps] : [])' docs/spec.md
grep -F "lastSavedReps" docs/spec.md
grep -F '0rep 세션' docs/spec.md
grep -F '$0.totalReps > 0' docs/spec.md
grep -F 'autosave failed' docs/spec.md

# 3) spec.md §3.1 주석 추가
grep -F '진행 중 세트의 임시 snapshot' docs/spec.md

# 4) spec.md §5 분기 테이블 수정
grep -F 'SwiftData autosave — 세션 첫 세트 시작 insert + 매 rep snapshot save' docs/spec.md
grep -F '세트 종료 시 1회' docs/spec.md

# 5) user-intervention.md 신규 섹션
grep -F '### 트래킹 autosave 실기기 QA (task 5-rep-autosave)' docs/user-intervention.md
grep -F '위로 스와이프해 강제 종료' docs/user-intervention.md
grep -F '2rep 세션이 표시' docs/user-intervention.md
grep -F '세션 카드가 노출되지 않아야 한다' docs/user-intervention.md
grep -F 'QA OK' docs/user-intervention.md

# 6) Mixpanel 관련 문구 미추가
! grep -F 'Mixpanel dashboard' docs/user-intervention.md
! grep -F 'workout_set_started' docs/user-intervention.md

# 7) 코드 디렉토리 무변경
git diff --quiet HEAD -- Mofit/ server/ scripts/ README.md project.yml

# 8) docs/ 변경 범위 — adr.md + spec.md + user-intervention.md (최소 3개), code-architecture.md 는 선택
CHANGED_DOCS=$(git diff --name-only HEAD -- docs/ | sort)
echo "$CHANGED_DOCS" | grep -qF 'docs/adr.md'
echo "$CHANGED_DOCS" | grep -qF 'docs/spec.md'
echo "$CHANGED_DOCS" | grep -qF 'docs/user-intervention.md'
# 나머지 문서는 수정 금지
! echo "$CHANGED_DOCS" | grep -qF 'docs/testing.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/data-schema.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/flow.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/prd.md'
! echo "$CHANGED_DOCS" | grep -qF 'docs/mission.md'

# 9) 미래 약속 문구 미포함
! grep -F '곧 지원' docs/adr.md
! grep -F '로드맵' docs/adr.md
! grep -F '차기 버전' docs/adr.md
! grep -F '곧 지원' docs/spec.md
! grep -F '곧 지원' docs/user-intervention.md
```

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `tasks/5-rep-autosave/index.json` 의 phase 0 status 를 `"completed"` 로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"` 로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

## 주의사항

- **ADR-009 원문 bullet 4줄은 불변**: `카메라 미인식`·`세트 완료 진동`·`앱 종료 시 운동 데이터 복구`·`SwiftData 마이그레이션` 줄 그대로 유지. Update 블록은 이 4줄 **뒤** 빈 줄 후 삽입.
- **spec.md §2.6 과 §2.5 의 렌더링 충돌 주의**: 기존 §2.5 튜닝 대상 bullet 마지막 줄 뒤 빈 줄 1개 확보한 뒤 §2.6 삽입. 연속된 h3 끼리 빈 줄 누락하면 markdown 렌더러에 따라 병합될 수 있다.
- **Mixpanel dashboard URL 기록 금지**: CTO 조건 4 (대시보드 URL) 는 `AnalyticsService` 선행 이후 별건 티켓. 이번 phase 에 URL/이벤트명을 추측으로 기입하지 마라.
- **스키마 변경 금지**: `docs/data-schema.md` 는 `WorkoutSession.repCounts: [Int]` 그대로. 수정하면 AC 8 실패.
- **docs-diff.md 는 직접 쓰지 마라**: Phase 0 완료 후 runner(`scripts/gen-docs-diff.py`) 가 자동 생성. `tasks/5-rep-autosave/docs-diff.md` 파일을 수동으로 만들지 마라.
- **기존 테스트를 깨뜨리지 마라**: docs 만 변경이라 테스트 영향 없음. 다만 `Mofit/` 파일을 실수로 건드리면 AC 7 실패.
- **git status 클린 상태 시작**: dirty 면 error 기록 후 중단.
