import XCTest
@testable import DynamicAPI
import Moya

// MARK: - Response Models

struct BilibiliBaseResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: T?
}

struct QRCodeData: Decodable {
    let url: String
    let qrcode_key: String
}

struct PollData: Decodable {
    let url: String
    let code: Int
    let message: String
}

// MARK: - Tests

final class BilibiliTests: XCTestCase {
    
    var client: DynamicAPIClient!
    
    override func setUpWithError() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "bilibili_config", withExtension: "json") else {
            XCTFail("Missing bilibili_config.json")
            return
        }
        let loader = try ConfigLoader.load(from: url)
        
        // 使用真实网络 Provider
        let provider = MoyaProvider<DynamicTarget>()
        client = DynamicAPIClient(configLoader: loader, provider: provider)
    }
    
    func testBilibiliLoginFlow() async throws {
        // Skip in CI/standard runs to avoid network dependency
        try XCTSkipIf(ProcessInfo.processInfo.environment["ENABLE_BILIBILI_TEST"] == nil, "Skipping Bilibili integration test. Set ENABLE_BILIBILI_TEST=1 to run.")

        // 1. 获取二维码
        let qrResponse: BilibiliBaseResponse<QRCodeData> = try await client.call("get_qrcode")
        
        XCTAssertEqual(qrResponse.code, 0, "API request failed")
        guard let qrData = qrResponse.data else {
            XCTFail("Missing QR Data")
            return
        }
        
        XCTAssertFalse(qrData.url.isEmpty)
        XCTAssertFalse(qrData.qrcode_key.isEmpty)
        
        // 2. 尝试轮询一次 (预期结果：未扫码)
        let pollParams = ["key": qrData.qrcode_key]
        let pollResponse: BilibiliBaseResponse<PollData> = try await client.call("poll_login", params: pollParams)
        
        XCTAssertEqual(pollResponse.code, 0, "Poll request failed")
        
        if let pollData = pollResponse.data {
            // 86101: 未扫码
            // 86090: 已扫码未确认
            // 0: 成功
            // 86038: 二维码失效
            
            // 只要不是 API 错误，都算测试通过。通常刚生成完立刻查应该是 86101
            XCTAssertTrue([86101, 86090, 0, 86038].contains(pollData.code), "Unexpected poll status code: \(pollData.code)")
        } else {
            XCTFail("Missing Poll Data")
        }
    }
}
