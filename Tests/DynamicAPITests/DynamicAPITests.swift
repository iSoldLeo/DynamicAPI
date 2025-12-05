import XCTest
@testable import DynamicAPI
import Moya

final class DynamicAPITests: XCTestCase {
    
    var configLoader: ConfigLoader!
    
    override func setUpWithError() throws {
        guard let url = Bundle.module.url(forResource: "Endpoints", withExtension: "json") else {
            XCTFail("Missing Endpoints.json")
            return
        }
        configLoader = try ConfigLoader.load(from: url)
    }
    
    func testLoadConfig() {
        XCTAssertEqual(configLoader.config.version, "1.0.0")
        XCTAssertEqual(configLoader.config.globals.baseURL, "https://api.example.com/v1")
        XCTAssertNotNil(configLoader.config.operations["get_user"])
    }
    
    func testResolveOperation_GetUser() throws {
        let op = try configLoader.resolve(operation: "get_user")
        XCTAssertEqual(op.path, "/users/$user_id")
        XCTAssertEqual(op.method, .get)
        XCTAssertEqual(op.headers["User-Agent"], "DynamicAPI/1.0")
        XCTAssertEqual(op.params["include_details"] as? String, "true")
    }
    
    func testResolveOperation_NotExists() {
        XCTAssertThrowsError(try configLoader.resolve(operation: "not_exists")) { error in
            guard let err = error as? DynamicAPIError, case .configurationError(let reason) = err else {
                XCTFail("Should throw configurationError")
                return
            }
            XCTAssertTrue(reason.contains("not found"))
        }
    }
    
    func testResolveOperation_WithHeaders() throws {
        // Assuming "get_user" has headers defined in Endpoints.json based on previous test
        let op = try configLoader.resolve(operation: "get_user")
        XCTAssertEqual(op.headers["User-Agent"], "DynamicAPI/1.0")
        // If there are other headers in Endpoints.json, we could test them here.
        // Based on context, "User-Agent" seems to be the one.
    }
    
    func testResolveOperation_ListFeed_WithPresets() throws {
        let op = try configLoader.resolve(operation: "list_feed")
        XCTAssertEqual(op.path, "/feed")
        XCTAssertEqual(op.params["page"] as? String, "1") // From preset
        XCTAssertEqual(op.params["limit"] as? String, "20") // From preset
        XCTAssertEqual(op.params["type"] as? String, "$feed_type")
        XCTAssertEqual(op.responseMapping, "FeedMapper")
    }
    
    func testProfileOverride() throws {
        configLoader.currentProfile = "dev"
        let op = try configLoader.resolve(operation: "get_user")
        XCTAssertEqual(op.baseURL.absoluteString, "https://dev-api.example.com/v1")
    }
    
    func testParamResolution() throws {
        let op = try configLoader.resolve(operation: "get_user")
        let runtimeValues: [String: Any] = ["user_id": 123]
        
        let target = try DynamicTarget(operation: op, runtimeValues: runtimeValues)
        
        XCTAssertEqual(target.path, "/users/123")
        XCTAssertEqual(target.resolvedParams["include_details"] as? String, "true")
    }
    
    func testMissingParamError() {
        do {
            let op = try configLoader.resolve(operation: "get_user")
            _ = try DynamicTarget(operation: op, runtimeValues: [:])
            XCTFail("Should throw missing parameter error")
        } catch DynamicAPIError.parameterError(_, let key) {
            XCTAssertEqual(key, "user_id")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testBodyResolution() throws {
        let op = try configLoader.resolve(operation: "create_post")
        let runtimeValues: [String: Any] = ["title": "Hello", "content": "World"]
        
        let target = try DynamicTarget(operation: op, runtimeValues: runtimeValues)
        
        let bodyDict = target.resolvedBody?.value as? [String: Any]
        XCTAssertEqual(bodyDict?["title"] as? String, "Hello")
        XCTAssertEqual(bodyDict?["content"] as? String, "World")
        
        if case .requestParameters(let parameters, let encoding) = target.task {
            XCTAssertNotNil(parameters)
            XCTAssertTrue(encoding is JSONEncoding)
        } else {
            XCTFail("Task should be requestParameters with JSONEncoding")
        }
    }
}
