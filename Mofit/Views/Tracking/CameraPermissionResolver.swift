// iter 8 (task 7-camera-permission-recovery): 카메라 권한 상태 → 분기 decision 매핑.
// Foundation + AVFoundation(AVAuthorizationStatus enum 접근 한정). runtime API 호출 금지.
// spec §2.8, ADR-019.

import AVFoundation
import Foundation

enum CameraPermissionDecision: Equatable {
    case ready
    case requestInline
    case showSettingsFallback
}

struct CameraPermissionResolver {
    static func decide(status: AVAuthorizationStatus) -> CameraPermissionDecision {
        switch status {
        case .authorized:
            return .ready
        case .notDetermined:
            return .requestInline
        case .denied, .restricted:
            return .showSettingsFallback
        @unknown default:
            return .showSettingsFallback
        }
    }
}
