import XCTest
@testable import DynamicAPI
import Moya

final class DynamicTargetTests: XCTestCase {
    
    var loader: ConfigLoader!
    
    override func setUpWithError() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "full_config", withExtension: "json") else { return }
        loader = try ConfigLoader.load(from: url)
    }
    
    // R01: URL 拼接 & R02: 路径参数替换
    func testURLBuildingAndPathReplacement() throws {
        let op = try loader.resolve(operation: "get_user")
        let target = try DynamicTarget(operation: op, runtimeValues: ["id": "123", "req_id": "abc"])
        
        XCTAssertEqual(target.baseURL.absoluteString, "https://api.example.com")
        XCTAssertEqual(target.path, "/users/123")
        XCTAssertEqual(target.method, .get)
    }
    
    func testMissingRequiredPathParam() throws {
        let op = try loader.resolve(operation: "get_user")
        // Missing 'id'
        XCTAssertThrowsError(try DynamicTarget(operation: op, runtimeValues: ["req_id": "abc"])) { error in
            guard let err = error as? DynamicAPIError, case .parameterError(let reason, let param) = err else {
                XCTFail("Should throw parameterError")
                return
            }
            XCTAssertEqual(param, "id")
            XCTAssertTrue(reason.contains("Missing"))
        }
    }
    
    func testHeaderPlaceholderResolution() throws {
        let op = try loader.resolve(operation: "get_user")
        let target = try DynamicTarget(operation: op, runtimeValues: ["id": "123", "req_id": "req-12345"])
        
        XCTAssertEqual(target.headers?["X-Request-ID"], "req-12345")
        // Verify global headers are also present (if merged by ConfigLoader, but DynamicTarget might only hold operation headers + globals merged? 
        // Actually DynamicTarget usually holds the final headers. Let's check if globals are merged in resolve or DynamicTarget.
        // Usually resolve merges them.
        XCTAssertEqual(target.headers?["User-Agent"], "DynamicAPI/1.0")
    }

    // R03: URL 编码
    func testURLEncoding() throws {
        let op = try loader.resolve(operation: "get_user")
        // ID contains special chars
        let target = try DynamicTarget(operation: op, runtimeValues: ["id": "user/name", "req_id": "abc"])
        
        // Should be encoded to user%2Fname
        XCTAssertEqual(target.path, "/users/user%2Fname")
    }
    
    // R04: 参数合并优先级 & R06: 参数缺失
    func testParamResolution() throws {
        let op = try loader.resolve(operation: "search_items")
        
        // Missing 'query'
        XCTAssertThrowsError(try DynamicTarget(operation: op, runtimeValues: [:])) { error in
            guard let err = error as? DynamicAPIError, case .parameterError(let reason, let param) = err else {
                XCTFail("Should throw parameterError")
                return
            }
            XCTAssertEqual(param, "query")
            XCTAssertTrue(reason.contains("Missing"))
        }
        
        // Valid params
        let target = try DynamicTarget(operation: op, runtimeValues: ["query": "swift"])
        XCTAssertEqual(target.resolvedParams["q"] as? String, "swift")
        XCTAssertEqual(target.resolvedParams["sort"] as? String, "desc") // Default from config
        XCTAssertEqual(target.resolvedParams["page"] as? String, "1") // From preset
    }
    
    // R05: Body 构建
    func testBodyBuilding() throws {
        let op = try loader.resolve(operation: "create_order")
        let target = try DynamicTarget(operation: op, runtimeValues: ["pid": "p100", "qty": 5])
        
        XCTAssertNotNil(target.resolvedBody)
        let bodyDict = target.resolvedBody?.value as? [String: Any]
        XCTAssertEqual(bodyDict?["product_id"] as? String, "p100")
        XCTAssertEqual(bodyDict?["quantity"] as? Double, 5)
        
        // Verify Task Type
        if case .requestCompositeParameters(let bodyParams, _, _) = target.task {
             XCTAssertEqual(bodyParams["product_id"] as? String, "p100")
        } else if case .requestParameters(let params, _) = target.task {
             // Depending on implementation, it might be requestParameters if no query params
             XCTAssertEqual(params["product_id"] as? String, "p100")
        } else {
            XCTFail("Task should have parameters")
        }
    }
    
    // R07: 多余参数 (Should be ignored in resolvedParams/Body, but kept in runtimeValues is fine)
    // The current implementation of ParamResolver only picks keys defined in templates.
    func testExtraParamsIgnored() throws {
        let op = try loader.resolve(operation: "get_user")
        // get_user requires "req_id" in headers
        let _ = try DynamicTarget(operation: op, runtimeValues: ["id": "123", "req_id": "abc", "extra": "ignored"])
        
        // resolvedParams should be empty for get_user as it has no query params defined in config
        // Wait, get_user has headers with $req_id, but no params.
        // Let's check search_items which has params.
        
        let opSearch = try loader.resolve(operation: "search_items")
        let targetSearch = try DynamicTarget(operation: opSearch, runtimeValues: ["query": "swift", "extra": "ignored"])
        
        XCTAssertNil(targetSearch.resolvedParams["extra"])
        XCTAssertEqual(targetSearch.resolvedParams["q"] as? String, "swift")
    }
}
