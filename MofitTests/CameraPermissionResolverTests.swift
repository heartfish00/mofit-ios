import AVFoundation
import XCTest
@testable import Mofit

final class CameraPermissionResolverTests: XCTestCase {

    func test_decide_authorized_returnsReady() {
        XCTAssertEqual(
            CameraPermissionResolver.decide(status: .authorized),
            .ready
        )
    }

    func test_decide_denied_returnsShowSettingsFallback() {
        XCTAssertEqual(
            CameraPermissionResolver.decide(status: .denied),
            .showSettingsFallback
        )
    }

    func test_decide_restricted_returnsShowSettingsFallback() {
        XCTAssertEqual(
            CameraPermissionResolver.decide(status: .restricted),
            .showSettingsFallback
        )
    }

    func test_decide_notDetermined_returnsRequestInline() {
        XCTAssertEqual(
            CameraPermissionResolver.decide(status: .notDetermined),
            .requestInline
        )
    }
}
