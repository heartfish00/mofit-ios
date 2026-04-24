# docs-diff: rep-autosave

Baseline: `3b12ec6`

## `docs/adr.md`

```diff
diff --git a/docs/adr.md b/docs/adr.md
index 9bdc6f5..cf5000f 100644
--- a/docs/adr.md
+++ b/docs/adr.md
@@ -49,6 +49,13 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 - 앱 종료 시 운동 데이터 복구 → 복잡도 대비 발생 빈도 낮음
 - SwiftData 마이그레이션 → 출시 전 스키마 확정으로 회피
 
+**2026-04-24 업데이트 (task 5-rep-autosave)**: "앱 종료 시 운동 데이터 복구 → 발생 빈도 낮음" 항목의 delta — rep 단위 autosave 도입(비로그인 유저 한정).
+- persist 시점을 **세트 종료 시 1회 insert** → **세션(TrackingView lifecycle) 첫 세트 시작 시 1회 insert + 매 rep 증가 시 `WorkoutSession.repCounts` snapshot update + `try? modelContext.save()`** 로 이동.
+- `WorkoutSession` 스키마 **불변**. `isInProgress` 플래그 추가 금지. 복구 UI / "이어하기" 시트 / HomeView 재개 버튼 / `workout_interrupted_*` analytics 이벤트 / UserDefaults 별도 저장 경로 **모두 여전히 제외**.
+- 로그인 유저 경로는 불변 — 서버 `POST /sessions` 로 세트 종료 시 1회 저장 (ADR-013, ADR-014 유지).
+- 트레이드오프: (a) 0rep 빈 세션이 SwiftData 에 기록될 수 있음 → `RecordsView` 에서 `$0.totalReps > 0` 메모리 필터로 숨김. (b) `WorkoutSession.repCounts` 의 마지막 요소는 tracking 중에는 "진행 중 세트의 임시 snapshot", `completeSet` / `stopSession` 이후에는 "확정된 세트 합계" 로 상태가 바뀐다. 독자 혼동 방지를 위해 `docs/spec.md §3.1` 에 주석 추가.
+- Phase 2(이어하기 UI) 트리거 임계는 `workout_set_started` / `workout_set_completed` Mixpanel 이벤트 비율 5% 주간 초과. **단 현재 `AnalyticsService` 미도입 상태** — Phase 2 는 analytics 인프라 선행 후 별건 티켓으로 다룬다.
+
 ### ADR-010: 커스텀 JWT 인증 (Supabase Auth 미사용)
 **결정**: Supabase는 순수 DB로만 사용. bcrypt + JWT를 서버에서 직접 구현.
 **이유**: Supabase Auth의 이메일 기반 로그인이 제공하는 기능 대비, 직접 구현이 더 간단하고 제어 가능. 의존성 최소화.
```

## `docs/spec.md`

```diff
diff --git a/docs/spec.md b/docs/spec.md
index 6d93ca0..601b75a 100644
--- a/docs/spec.md
+++ b/docs/spec.md
@@ -96,6 +96,18 @@ AVCaptureSession (전면)
   - `.lowLight`: "조명이 어두울 수 있어요 · 실내 조명을 밝혀주세요"
 - **튜닝 대상**: grace 5s, sustain 3s, lowLight confidence 0.5. 전부 `TrackingViewModel` 내 `private enum Diagnostic` 에 상수화. 운영 중 튜닝은 이 enum 만 수정.
 
+### 2.6 트래킹 autosave (비로그인 한정)
+
+비로그인 유저의 `TrackingView` 세션은 SwiftData 에 rep 단위로 자동 저장된다. pain 대응: 트래킹 중 전화/앱 전환/크래시가 발생해도 기록 탭에 현재까지의 rep 수가 남는다(ADR-009 업데이트).
+
+- **insert 시점**: 세션 생애 첫 `startCountdown()` 호출(= `hasStartedElapsedTimer` 가 false → true 로 전이하는 순간) 에서 `WorkoutSession(startedAt: sessionStartTime, repCounts: [])` 을 1회 insert. 2번째 이후 세트 시작에서는 재 insert 없음.
+- **snapshot update 시점**: Counter 의 `@Published currentReps` 가 갱신될 때마다 `session.repCounts = self.repCounts + (currentReps > 0 ? [currentReps] : [])` 로 배열 교체 + `session.endedAt = Date()` + `session.totalDuration = elapsedTime` + `try? modelContext.save()`. `lastSavedReps` no-op 가드로 동일 값 재방출 시 save 스킵.
+- **completeSet 시점**: `self.repCounts.append(currentReps)` 직후 같은 session 에 `session.repCounts = self.repCounts` 로 확정 값 덮어쓰기 + save. tail 재삽입 없음.
+- **stopSession 시점**: (비로그인) `session.repCounts = self.repCounts` + `endedAt` / `totalDuration` 최종 반영 + save. `currentSession = nil` 로 해제. `modelContext.insert` 는 호출하지 않음 (이미 insert 완료).
+- **로그인 유저**: 전부 스킵. 기존 `POST /sessions` 서버 저장 경로 유지(ADR-013, ADR-014).
+- **에러 정책**: save 실패는 `print("autosave failed: \(error)")` 만 남기고 `saveError` / alert 건드리지 않음. 트래킹 중 UI 방해 절대 금지.
+- **0rep 세션**: insert 됐지만 rep 한 번도 안 들어오고 stopSession 호출된 세션은 `repCounts=[]` 로 남음. `RecordsView` 가 `$0.totalReps > 0` 필터로 숨김. SwiftData 에는 소량 남지만 UX 영향 0.
+
 ---
 
 ## 3. 데이터 모델
@@ -106,6 +118,7 @@ AVCaptureSession (전면)
 
 - `UserProfile` (싱글톤): `gender`, `height`, `weight`, `bodyType`, `goal`, `onboardingCompleted`
 - `WorkoutSession`: `id`, `exerciseType`, `startedAt`, `endedAt`, `totalDuration`, `repCounts: [Int]`
+  - **주의**: tracking 중에는 `repCounts` 의 마지막 요소가 "진행 중 세트의 임시 snapshot" 이며, `completeSet` / `stopSession` 이후에는 "확정된 세트 합계" 로 상태가 전환된다 (§2.6 autosave).
 - `CoachingFeedback`: `id`, `date`, `type` (pre/post), `content`, `createdAt`
 
 **핵심 결정 (ADR-003)**: 세트는 별도 모델 없음. `repCounts: [Int]` 배열로 표현. `세트 수 = repCounts.count`, `총 rep = repCounts.sum()`.
@@ -180,7 +193,7 @@ Node.js + Express. Railway 배포. JWT(bcrypt 해시). 모든 보호된 라우
 
 | 액션           | 로그인 유저                          | 비로그인 유저                   |
 | -------------- | ------------------------------------ | ------------------------------- |
-| 운동 완료 저장 | `POST /sessions`                     | SwiftData 로컬 저장             |
+| 운동 완료 저장 | `POST /sessions` (세트 종료 시 1회)    | SwiftData autosave — 세션 첫 세트 시작 insert + 매 rep snapshot save (§2.6) |
 | 프로필 수정    | `PUT /profile`                       | SwiftData 로컬 저장             |
 | 기록 조회      | `GET /sessions`                      | SwiftData fetch                 |
 | AI 코칭        | `POST /coaching/request`             | **사용 불가** (AuthGateView)    |
```

## `docs/user-intervention.md`

```diff
diff --git a/docs/user-intervention.md b/docs/user-intervention.md
index 4fb1b0e..fe6c9d9 100644
--- a/docs/user-intervention.md
+++ b/docs/user-intervention.md
@@ -43,6 +43,20 @@ cc-system `plan-and-build` skill 원칙: **모든 구현은 CLI + AI 에이전
 
 ---
 
+### 트래킹 autosave 실기기 QA (task 5-rep-autosave)
+
+- **트리거**: task `5-rep-autosave` 의 PR merge 직전 1회.
+- **이유**: SwiftData 의 실제 flush 타이밍 / 앱 강제 종료 후 재실행 시 `@Query` refetch 가 단위 테스트 (in-memory ModelContainer) 로는 완벽히 재현되지 않음. iteration §CTO 승인 조건부 5 의 "실기기 QA 1회 (merge 전)" 대응.
+- **절차**:
+  1. **정상 경로 (a)**: 비로그인 상태로 앱 실행 → 홈 → "스쿼트 시작" → 5초 카운트다운 → 트래킹 진입 → 스쿼트 3rep 수행 → 손바닥 1초 또는 화면 탭으로 세트 종료 → 결과 화면 → 홈 복귀 → 기록 탭 진입. **오늘 날짜에 3rep 세션이 표시되어야 한다**.
+  2. **크래시 복구 (b)**: 비로그인 상태로 트래킹 진입 → 스쿼트 2rep 수행(종료 트리거 **누르지 말 것**) → iOS 앱 스위처에서 Mofit 을 **위로 스와이프해 강제 종료** → 앱 재실행 → 기록 탭 진입. **오늘 날짜에 2rep 세션이 표시되어야 한다**. "이어하기" 버튼/시트는 **없는 게 정상** (scope 외).
+  3. **0rep 필터 (c)**: 비로그인 상태로 트래킹 진입 → rep 한 번도 올리지 않고 닫기(x) 또는 정지 버튼 → 기록 탭 진입. **오늘 날짜에 세션 카드가 노출되지 않아야 한다** (0rep 필터).
+  4. **로그인 경로 불변 (d)**: 로그인 상태로 트래킹 진입 → 스쿼트 3rep → 세트 종료 → 기록 탭 진입. **오늘 날짜에 3rep 세션이 서버에서 로드되어 표시되어야 한다** (로그인 경로가 이번 task 로 회귀하지 않았는지 smoke). 크래시 후 복구는 로그인 유저에서 기대하지 않는다(Phase 1 scope 외, ADR-013).
+- **재개 신호**: 사용자가 에이전트에게 "QA OK" 라고 알려주면 merge 승인. (a)(b)(c)(d) 중 하나라도 실패 시 재현 조건을 공유하고 phase 1 재실행.
+- **기록 위치**: PR 설명에 QA 수행 일시 + (a)(b)(c)(d) 각각의 pass/fail 기록.
+
+---
+
 ## 주의
 
 - **Secrets**: 새 API 키가 필요한 경우 `Mofit/Config/Secrets.swift` 또는 `server/.env` 를 직접 편집해야 할 수 있다. 두 파일 모두 `.gitignore` 이므로 에이전트도 Read 로만 접근해야 한다.
```
