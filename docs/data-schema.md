# 데이터 스키마 (SwiftData)

## 모델

### UserProfile
싱글톤. 앱 전체에서 1개만 존재.
```swift
@Model class UserProfile {
    var gender: String          // "male" | "female"
    var height: Double          // cm
    var weight: Double          // kg
    var bodyType: String        // "slim" | "normal" | "muscular" | "chubby"
    var goal: String            // "weightLoss" | "strength" | "bodyShape"
    var onboardingCompleted: Bool
}
```

### WorkoutSession
운동 1회 = 1 세션. 하루에 여러 세션 가능.
```swift
@Model class WorkoutSession {
    var id: UUID
    var exerciseType: String    // "squat" (MVP에서는 전부 이 값)
    var startedAt: Date
    var endedAt: Date
    var totalDuration: Int      // 초. 첫 카운트다운 시작 ~ 종료 버튼
    var repCounts: [Int]        // 세트별 rep. [12, 10, 8] = 3세트
}
```
- 별도 WorkoutSet 모델 없음. repCounts 배열로 단순화.
- `세트 수 = repCounts.count`, `총 rep = repCounts.sum()`

### CoachingFeedback
```swift
@Model class CoachingFeedback {
    var id: UUID
    var date: Date              // 날짜 (하루 2회 제한 체크용)
    var type: String            // "pre" | "post"
    var content: String         // AI 응답 전문
    var createdAt: Date
}
```

## AI 코칭 Context 구조
Claude API 호출 시 넘기는 데이터:
```
사용자: { gender, height, weight, bodyType, goal }
최근 7일 요약: { 운동일수, 총세션, 총rep, 일평균rep }
추이 (일별): { rep[], 세트수[], 세트당평균rep[] }
```
토큰 절약을 위해 7일로 제한. 추이 데이터로 AI가 경향성 기반 조언 가능.
