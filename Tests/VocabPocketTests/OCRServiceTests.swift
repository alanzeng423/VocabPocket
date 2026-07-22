import Foundation
import XCTest

@testable import VocabPocket

final class OCRServiceTests: XCTestCase {
    func testInvalidImageHasActionableError() async {
        do {
            _ = try await OCRService().recognizeText(in: Data("not an image".utf8))
            XCTFail("Expected invalid image error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "截图文件无效，请重新框选文字区域")
        }
    }
}
