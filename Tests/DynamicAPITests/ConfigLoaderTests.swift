import XCTest
@testable import DynamicAPI
import Moya

final class ConfigLoaderTests: XCTestCase {
    
    var loader: ConfigLoader!
    
    override func setUpWithError() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "full_config", withExtension: "json") else {
            XCTFail("Missing full_config.json")
            return
        }
        loader = try ConfigLoader.load(from: url)
    }
    
    // C01: 基础合法性
    func testLoadValidConfig() {
        XCTAssertNotNil(loader.config)
        XCTAssertEqual(loader.config.version, "1.0")
        XCTAssertEqual(loader.config.globals.baseURL, "https://api.example.com")
        XCTAssertEqual(loader.config.operations.count, 4)
    }
    
    // C02: 必填字段缺失 (测试 invalid_config.json)
    func testLoadInvalidConfig() {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "invalid_config", withExtension: "json") else {
            XCTFail("Missing invalid_config.json")
            return
        }
        
        // 应该抛出 Decoding Error，因为 path 是必填的
        XCTAssertThrowsError(try ConfigLoader.load(from: url)) { error in
            XCTAssertTrue(error is DecodingError, "Should be a decoding error due to missing keys")
        }
    }
    
    // C04: DRY - Profile 继承
    func testProfileInheritance() throws {
        // 默认 Globals
        let opDefault = try loader.resolve(operation: "get_user")
        XCTAssertEqual(opDefault.baseURL.absoluteString, "https://api.example.com")
        XCTAssertEqual(opDefault.headers["User-Agent"], "DynamicAPI/1.0")
        
        // 切换 Profile
        loader.currentProfile = "dev"
        let opDev = try loader.resolve(operation: "get_user")
        XCTAssertEqual(opDev.baseURL.absoluteString, "https://dev.api.example.com")
        XCTAssertEqual(opDev.headers["X-Environment"], "Development")
        XCTAssertEqual(opDev.headers["User-Agent"], "DynamicAPI/1.0", "Should inherit global headers")
    }
    
    // C05: DRY - Operation 覆盖
    func testOperationOverride() throws {
        // Operation 'get_user' defines X-Request-ID, Globals defines User-Agent
        let op = try loader.resolve(operation: "get_user")
        XCTAssertNotNil(op.headers["X-Request-ID"])
        XCTAssertNotNil(op.headers["User-Agent"])
    }
    
    // C06: Param Presets 展开
    func testParamPresets() throws {
        let op = try loader.resolve(operation: "search_items")
        
        // Presets: pagination (page, limit), device_info (platform, version)
        // Operation: q, sort
        
        XCTAssertEqual(op.params["page"] as? String, "1")
        XCTAssertEqual(op.params["limit"] as? String, "20")
        XCTAssertEqual(op.params["platform"] as? String, "ios")
        XCTAssertEqual(op.params["q"] as? String, "$query")
        XCTAssertEqual(op.params["sort"] as? String, "desc")
    }
    
    // C07: 配置一致性检查 (不存在的 Operation)
    func testMissingOperation() {
        XCTAssertThrowsError(try loader.resolve(operation: "non_existent_op")) { error in
            guard let err = error as? DynamicAPIError, case .configurationError = err else {
                XCTFail("Should throw configurationError")
                return
            }
        }
    }
}
