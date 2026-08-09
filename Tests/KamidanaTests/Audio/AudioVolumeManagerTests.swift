import XCTest
@testable import Kamidana

final class AudioVolumeManagerTests: XCTestCase {

    func testAudioVolumeManager() {
        let manager = AudioVolumeManager()
        
        let outVol = manager.outputVolume()
        print("🔊 デフォルト出力音量: \(outVol.value) (ミュート: \(outVol.muted))")
        
        // 音量取得でクラッシュしないことを確認
        XCTAssertTrue(outVol.value >= 0.0 && outVol.value <= 1.0, "音量は0.0〜1.0の範囲であること")
        
        // （注意）実際に音量を変更するテストはユーザー環境に影響を与えるため、
        // CI等では実行しない、あるいは元に戻す処理を入れる必要があります。
        // 今回は取得処理のみ検証します。
    }
}
