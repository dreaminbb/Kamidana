import XCTest
import CoreAudio
@testable import Kamidana

final class AudioDeviceManagerTests: XCTestCase {

    func testDefaultOutputDevice() {
        let manager = AudioDeviceManager()
        
        // テスト環境（Mac）でデフォルトの出力デバイスが存在するかを確認します
        let outputDevice = manager.defaultOutput()
        
        // 開発機やCI環境によってはオーディオデバイスが無い可能性もあるため、
        // 必ずしも取得できるとは限りませんが、処理がクラッシュせずに通ることを確認します。
        XCTAssertNoThrow(manager.defaultOutput(), "デフォルト出力デバイスの取得でクラッシュしないこと")
        
        if let device = outputDevice {
            print("🔊 テスト成功: デフォルト出力デバイス名 = \(device.name)")
            XCTAssertFalse(device.name.isEmpty, "デバイス名が空ではないこと")
            XCTAssertTrue(device.isOutput, "出力デバイスフラグがtrueであること")
            
            // フォーマット情報の取得テスト
            if let format = manager.getPhysicalFormat(deviceID: device.id, scope: kAudioObjectPropertyScopeOutput) {
                print("🔊 フォーマット: \(format.bitDepth) bit \(format.formatFlagsName) \(format.formatName), \(format.sampleRate) Hz")
                XCTAssertTrue(format.sampleRate > 0, "サンプルレートが取得できること")
            } else {
                print("⚠️ フォーマット情報が取得できませんでした")
            }
            
        } else {
            print("⚠️ オーディオ出力デバイスが見つかりませんでしたが、エラーにはなりませんでした。")
        }
    }
}
