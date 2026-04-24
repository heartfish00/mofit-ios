# docs-diff: squat-only-pivot

Baseline: `675b86d`

## `docs/adr.md`

```diff
diff --git a/docs/adr.md b/docs/adr.md
index ca641c6..1471358 100644
--- a/docs/adr.md
+++ b/docs/adr.md
@@ -39,6 +39,7 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 **이유**: 무채색 기반 디자인이 다크모드에서 가장 자연스러움. 라이트/다크 두 벌 디자인 불필요 → 개발 속도 향상.
 
 ### ADR-008: 운동 선택 UI는 있되 내부 처리는 스쿼트 통일
+**SUPERSEDED by ADR-017** — 스쿼트 전용 포지셔닝으로 전환. 운동 선택 UI 자체가 제거됨.
 **결정**: 4종 운동 선택 UI 제공, 내부적으로 전부 스쿼트로 처리.
 **이유**: UI 완성도 + 확장 가능성 확보. 사용자 입장에서 앱이 "하나만 되는 앱"으로 보이지 않게. 실제 운동별 판정 로직은 검증 후 점진적 추가.
 
@@ -79,6 +80,13 @@ MVP 속도 최우선. 외부 의존성 0, 최소 화면, 최소 기능. 안정
 **대안 검토**: Firebase Analytics(plist 설정 복잡, CLI 완결 불가), Amplitude(행동분석 UX가 Mixpanel보다 약간 열세), PostHog(모바일 SDK 성숙도 낮음).
 
 ### ADR-016: 스쿼트 외 운동은 "준비중" UI로 공개 (ADR-008 보완)
+**SUPERSEDED by ADR-017** — "준비중" UI 자체가 제거됨. 스쿼트 전용 포지셔닝으로 전환.
 **결정**: ExercisePicker에서 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4의 비활성화 톤으로 표시. tap 자체는 차단하지 않되, selected 전환/화면 dismiss 대신 토스트 "현재는 스쿼트만 지원합니다"만 1.5초 노출하고 트래킹 진입은 차단.
 **이유**: ADR-008("UI는 있되 내부 전부 스쿼트 통일")은 3일 체험 페르소나가 푸쉬업을 한 번만 눌러봐도 기대 불일치가 드러나 즉시 삭제 트리거가 됨 (시뮬 run_id: home-workout-newbie-20s_20260424_153242). 기능 다양성 과시보다 신뢰도 우선.
 **트레이드오프**: 운동별 판정 로직이 추가될 때까지 선택지 다양성 축소. 셀 tap 자체는 남겨둬 향후 재활성화 시 회귀 테스트 누락 리스크를 줄임. 토스트 카피에는 "곧 지원됩니다" 같은 미래 약속 문구 금지.
+
+### ADR-017: 스쿼트 전용 포지셔닝 확정 (ADR-008, ADR-016 대체)
+**결정**: ExercisePickerView 파일 삭제 + HomeView의 운동 종류 선택 드롭다운 제거. "스쿼트 시작" 고정 CTA 로 전환. 랜딩/README/docs 카피에서 "홈트/운동 종류" 언어를 "스쿼트"로 정돈. 미래 약속 문구(곧 지원됩니다, 로드맵 등) 금지.
+**이유**: iter 4 설득력 검토(run_id: home-workout-newbie-20s_20260424_193756)에서 "홈트 기대 설치 → 3일 안에 스쿼트 전용임 인지 → 무료 스쿼트 카운터로 전환" 이탈 경로가 keyman 최종 판정 실패의 독립적 reject 사유. "준비중" UI 를 남겨두는 것만으로도 `personality_notes`("3일 써보고 아니면 삭제") + `switching_cost: low` 경쟁재 조건에서 기대 불일치가 드러남. 포지셔닝 자체를 스쿼트 전용으로 좁혀 기대-실제 갭을 제거.
+**트레이드오프**: 푸쉬업/싯업 확장 시 운동 종류 선택 UI/상태를 복구해야 함. 단, `TrackingViewModel.exerciseType` 분기 + `PushUpCounter.swift`/`SitUpCounter.swift` 내부 판정 자산은 보존(CTO 조건부 #1)하여 재활성화 비용 최소화. 이번 삭제는 View 레이어 한정.
+**범위**: `Mofit/Views/Home/ExercisePickerView.swift` 파일 삭제, `Mofit/Views/Home/HomeView.swift` 에서 `exerciseSelector`·`showExercisePicker`·`selectedExerciseName` 상태 제거. `TrackingView(exerciseType: "squat", ...)` 호출로 하드코딩. ADR-008/ADR-016 은 SUPERSEDED 표기 유지(역사 보존).
```

## `docs/code-architecture.md`

```diff
diff --git a/docs/code-architecture.md b/docs/code-architecture.md
index abbb8f3..ea3ff9e 100644
--- a/docs/code-architecture.md
+++ b/docs/code-architecture.md
@@ -19,8 +19,7 @@ Mofit/
 │   ├── Onboarding/
 │   │   └── OnboardingView.swift    # 단계별 온보딩 전체 (1파일)
 │   ├── Home/
-│   │   ├── HomeView.swift
-│   │   └── ExercisePickerView.swift
+│   │   └── HomeView.swift
 │   ├── Tracking/
 │   │   └── TrackingView.swift      # 카메라 프리뷰 + 상태별 오버레이
 │   ├── Records/
```

## `docs/flow.md`

```diff
diff --git a/docs/flow.md b/docs/flow.md
index 5726bd0..4b42add 100644
--- a/docs/flow.md
+++ b/docs/flow.md
@@ -17,8 +17,7 @@
 ## 2. 운동 흐름 (핵심)
 ```
 홈탭
-  → 운동 종류 탭 → 바텀시트 그리드 → 선택 → 시트 닫힘
-  → "운동 시작" 탭
+  → "스쿼트 시작" 탭
   → (최초 1회) 카메라 권한 요청
   → 트래킹 화면 진입
 
```

## `docs/mission.md`

```diff
diff --git a/docs/mission.md b/docs/mission.md
index 2fa9437..07138ac 100644
--- a/docs/mission.md
+++ b/docs/mission.md
@@ -42,5 +42,5 @@
 - 카메라 미인식 안내, 세트 완료 진동, 폰 위치 가이드
 - 앱 강제종료 시 운동 데이터 복구
 - SwiftData 마이그레이션
-- 스쿼트 외 운동의 별도 판정 로직 (UI는 노출, 내부는 스쿼트 통일)
+- 스쿼트 외 운동 (UI에도 노출하지 않음, ADR-017)
 - 로컬 → 서버 데이터 마이그레이션
```

## `docs/prd.md`

```diff
diff --git a/docs/prd.md b/docs/prd.md
index b938e71..98abbfb 100644
--- a/docs/prd.md
+++ b/docs/prd.md
@@ -25,15 +25,10 @@ MVP를 빠르게 출시하여 시장 반응을 검증한다 (YC 지원 대상).
 
 ### 홈탭
 - "모핏" 타이틀 (좌상단), 프로필 편집 버튼 (우상단)
-- 운동 종류 선택 영역 (탭 → 바텀시트 그리드)
-- 운동 시작 버튼 (형광초록, 크게)
-- 오늘의 기록 요약 (세트, rep, 시간). 기록 없으면 "첫 운동을 시작해보세요!"
+- "스쿼트 시작" 버튼 (형광초록, 크게) — 탭 시 바로 트래킹 화면 진입. 운동 종류 선택 UI 없음 (ADR-017)
+- 오늘의 기록 요약 (세트, 스쿼트, 시간). 기록 없으면 "첫 운동을 시작해보세요!"
 - 운동 종료 후 복귀 시 폭죽 효과
 
-### 운동 선택 (바텀시트)
-- 2열 그리드: 스쿼트 / 푸쉬업 / 싯업 (실코드 기준)
-- MVP에서는 스쿼트만 active. 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4로 비활성화 톤, tap 시 토스트 "현재는 스쿼트만 지원합니다"만 표시하고 트래킹 진입 차단. (ADR-016)
-
 ### 트래킹 화면
 - 전체화면 카메라 프리뷰 + 오버레이
 - 상태 머신: 대기 → 손바닥 1초 → 카운트다운 5초 → 운동 추적 → 손바닥 1초 → 세트 완료 + 카운트다운 5초 → 다음 세트 → ... → 종료
```

## `docs/spec.md`

```diff
diff --git a/docs/spec.md b/docs/spec.md
index 9228dc7..299525b 100644
--- a/docs/spec.md
+++ b/docs/spec.md
@@ -28,8 +28,7 @@ MofitApp
 ### 1.3 화면 목록
 
 - `OnboardingView` — 단계별(성별→키→몸무게→체형→목표)
-- `HomeView` — 오늘 요약 + 운동 시작
-- `ExercisePickerView` — 바텀시트 2열 그리드 (스쿼트/푸쉬업/싯업). 스쿼트만 active, 푸쉬업/싯업은 "준비중" 배지 + opacity 0.4로 비활성화 톤, tap 시 토스트 "현재는 스쿼트만 지원합니다"만 표시. (ADR-016)
+- `HomeView` — 오늘 요약 + "스쿼트 시작" 버튼 (운동 종류 선택 UI 없음, ADR-017)
 - `TrackingView` — 카메라 프리뷰 + 오버레이 + 상태머신
 - `RecordsView` — 날짜바 + 세션 리스트
 - `CoachingView` — AI 피드백 카드 + 운동 전/후 버튼
```
