import XCTest
@testable import SnapVault

@MainActor
final class PermissionServiceProtocolConformanceTests: XCTestCase {

    // TC-U-001: 三个 conformer(MockPermissionService、StaticPermissionService、PermissionService)
    // 都实现了 requestScreenRecordingPrompt()。此测试只覆盖两个 mock；真实 PermissionService
    // 走 CGRequestScreenCaptureAccess 会真弹 UI,不在单测中调用。
    // 参见 doc/iterations/v1.1.0/architecture/review.md 阻塞级发现。

    func test_mockPermissionService_conformsToRequestScreenRecordingPrompt() {
        let mock = MockPermissionService()
        mock.requestScreenRecordingResult = true
        let result = mock.requestScreenRecordingPrompt()
        XCTAssertTrue(result)
        XCTAssertEqual(mock.requestScreenRecordingCallCount, 1)
    }

    func test_staticPermissionService_conformsToRequestScreenRecordingPrompt() {
        let staticService = StaticPermissionService()
        XCTAssertTrue(staticService.requestScreenRecordingPrompt())
    }
}
