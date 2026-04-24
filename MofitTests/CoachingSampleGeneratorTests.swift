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
