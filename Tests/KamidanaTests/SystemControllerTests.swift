import XCTest
@testable import KamidanaApp

final class SystemControllerTests: XCTestCase {

    func testRunAppleScript_Success() {
        // 簡単な足し算をするAppleScript
        let script = "return 1 + 1"
        
        SystemController.runAppleScript(script)
    }

    func testRunAppleScript_Failure() {
        // 存在しないアプリケーションを操作しようとするAppleScript（エラーになる）
        let script = "tell application \"KamidanaNonExistentApp12345\" to activate"
        
        SystemController.runAppleScript(script)
    }
}
