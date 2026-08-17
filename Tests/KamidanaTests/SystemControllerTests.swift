import XCTest
@testable import Kamidana

final class SystemControllerTests: XCTestCase {

    func testRunAppleScript_Success() {
        // 簡単な足し算をするAppleScript
        let script = "return 1 + 1"
        
        let result = SystemController.runAppleScript(script)
        
        switch result {
        case .success(let isSuccess):
            XCTAssertTrue(isSuccess, "正しいAppleScriptは成功する必要があります")
        case .failure(let error):
            XCTFail("成功するはずのスクリプトが失敗しました。エラー: \(error)")
        }
    }

    func testRunAppleScript_Failure() {
        // 存在しないアプリケーションを操作しようとするAppleScript（エラーになる）
        let script = "tell application \"KamidanaNonExistentApp12345\" to activate"
        
        let result = SystemController.runAppleScript(script)
        
        switch result {
        case .success(_):
            XCTFail("不正なAppleScriptは失敗する必要がありますが、成功してしまいました")
        case .failure(let error):
            XCTAssertNotNil(error.localizedDescription, "エラーメッセージが取得できる必要があります")
            print("期待通りのエラー: \(error.localizedDescription)")
        }
    }
}
