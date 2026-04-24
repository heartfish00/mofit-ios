// iter 7 (task 6-coaching-generator): static samples → dynamic generator.
// `CoachingSamples.all` 정적 하드코딩 제거. `CoachingSampleGenerator` 가 온보딩 값 + 최근 7일 로컬 세션 기반으로 결정론적 생성 (spec §2.7, ADR-006 2026-04-24 업데이트).
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
