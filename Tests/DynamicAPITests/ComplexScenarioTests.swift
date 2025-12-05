import XCTest
@testable import DynamicAPI
import Moya

final class ComplexScenarioTests: XCTestCase {
    
    var loader: ConfigLoader!
    
    override func setUpWithError() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "complex_config", withExtension: "json") else {
            XCTFail("Missing complex_config.json")
            return
        }
        // 注意：在修复之前，这里可能会因为 JSON 解码失败而抛出错误
        // 为了让测试运行起来并验证后续逻辑，我们可能需要捕获这个错误，
        // 但为了遵循“黑盒测试”原则，我们直接尝试加载，如果失败则测试不通过，这符合预期。
        loader = try ConfigLoader.load(from: url)
    }
    
    // 验证嵌套 JSON Body 的支持
    // 预期：修复前会因为 APIConfig 类型不匹配而失败（在 setUp 或 resolve 阶段）
    func testNestedJSONBody() throws {
        let op = try loader.resolve(operation: "nested_body_op")
        let target = try DynamicTarget(operation: op, runtimeValues: [:])
        
        guard let body = target.resolvedBody?.value as? [String: Any] else {
            XCTFail("Body should not be nil and should be a dictionary")
            return
        }
        
        // 验证嵌套结构
        guard let user = body["user"] as? [String: Any] else {
            XCTFail("Body should contain 'user' object")
            return
        }
        
        XCTAssertEqual(user["id"] as? Double, 123)
        XCTAssertEqual(user["active"] as? Bool, true)
        
        // 验证数组
        guard let tags = body["tags"] as? [String] else {
            XCTFail("Body should contain 'tags' array")
            return
        }
        XCTAssertEqual(tags, ["a", "b"])
    }
    
    // 验证非 String 类型参数的支持
    // 预期：修复前会因为 APIConfig 类型不匹配而失败
    func testMixedTypesBody() throws {
        let op = try loader.resolve(operation: "mixed_types_op")
        let target = try DynamicTarget(operation: op, runtimeValues: [:])
        
        guard let body = target.resolvedBody?.value as? [String: Any] else {
            XCTFail("Body should not be nil and should be a dictionary")
            return
        }
        
        XCTAssertEqual(body["count"] as? Double, 42)
        XCTAssertEqual(body["score"] as? Double, 3.14)
        XCTAssertEqual(body["is_valid"] as? Bool, false)
    }
    
    // 验证 POST 请求仅带 Query 参数的情况
    // 预期：修复前，URLEncoding.default 会将参数放入 Body，导致 URL 中没有 Query 参数
    func testPostQueryNoBody() throws {
        let op = try loader.resolve(operation: "post_query_no_body_op")
        let target = try DynamicTarget(operation: op, runtimeValues: [:])
        
        // 验证 Task 类型
        switch target.task {
        case .requestParameters(let parameters, let encoding):
            XCTAssertEqual(parameters["id"] as? String, "123")
            
            // 关键验证：对于 POST 请求，如果想传 Query 参数，必须使用 URLEncoding.queryString
            // URLEncoding.default 在 POST 时会使用 httpBody
            XCTAssertTrue(encoding is URLEncoding, "Should be URLEncoding")
            if let urlEncoding = encoding as? URLEncoding {
                XCTAssertEqual(urlEncoding.destination, .queryString, "Encoding destination should be queryString for POST with params but no body content intended for body")
            }
        default:
            XCTFail("Unexpected task type: \(target.task)")
        }
    }
    
    func testPostBodyOnly() throws {
        let op = try loader.resolve(operation: "post_body_only_op")
        let target = try DynamicTarget(operation: op, runtimeValues: [:])
        
        switch target.task {
        case .requestParameters(_, let encoding):
            XCTAssertTrue(encoding is JSONEncoding, "Should be JSONEncoding by default for POST with body")
        case .requestJSONEncodable:
             // Also acceptable if implemented that way
             break
        default:
            XCTFail("Unexpected task type: \(target.task)")
        }
        
        guard let body = target.resolvedBody?.value as? [String: Any] else {
            XCTFail("Body should be present")
            return
        }
        XCTAssertEqual(body["name"] as? String, "New Item")
    }
    
    func testPostBodyAndQuery() throws {
        let op = try loader.resolve(operation: "post_body_and_query_op")
        let target = try DynamicTarget(operation: op, runtimeValues: [:])
        
        switch target.task {
        case .requestCompositeParameters(let bodyParams, _, let urlParams):
            XCTAssertEqual(bodyParams["status"] as? String, "active")
            XCTAssertEqual(urlParams["id"] as? String, "123")
        default:
            XCTFail("Unexpected task type: \(target.task). Should be requestCompositeParameters")
        }
    }
    
    func testGetQuery() throws {
        let op = try loader.resolve(operation: "get_query_op")
        let target = try DynamicTarget(operation: op, runtimeValues: [:])
        
        switch target.task {
        case .requestParameters(let params, let encoding):
            XCTAssertEqual(params["q"] as? String, "swift")
            XCTAssertTrue(encoding is URLEncoding)
            if let urlEncoding = encoding as? URLEncoding {
                XCTAssertEqual(urlEncoding.destination, .methodDependent) // or .queryString, methodDependent is default for GET
            }
        default:
            XCTFail("Unexpected task type: \(target.task)")
        }
    }
}
