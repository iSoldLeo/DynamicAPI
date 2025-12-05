import XCTest
import Moya
@testable import DynamicAPI

final class AdvancedEncodingTests: XCTestCase {
    
    func testPostDefaultEncodingUsesJSONEncoding() throws {
        let config = APIConfig(
            version: "1.0",
            globals: GlobalsConfig(baseURL: "https://api.example.com"),
            operations: [
                "post_default": OperationConfig(
                    path: "/post",
                    method: "POST",
                    params: ["key": AnyCodable("value")],
                    encoding: nil // Default
                )
            ]
        )
        
        let target = try DynamicTarget(
            config: config,
            endpointName: "post_default",
            runtimeParams: [:]
        )
        
        switch target.task {
        case .requestParameters(_, let encoding):
            XCTAssertTrue(encoding is JSONEncoding, "POST with nil encoding should default to JSONEncoding")
        default:
            XCTFail("Expected requestParameters")
        }
    }
    
    func testPostJsonEncodingWithBodyAndQueryUsesCompositeTask() throws {
        let config = APIConfig(
            version: "1.0",
            globals: GlobalsConfig(baseURL: "https://api.example.com"),
            operations: [
                "post_composite": OperationConfig(
                    path: "/post",
                    method: "POST",
                    params: ["q": AnyCodable("$q")], // Query param
                    body: AnyCodable(["b": "$b"]),   // Body param
                    encoding: "json"
                )
            ]
        )
        
        let target = try DynamicTarget(
            config: config,
            endpointName: "post_composite",
            runtimeParams: ["q": "queryVal", "b": "bodyVal"]
        )
        
        switch target.task {
        case .requestCompositeParameters(let bodyParameters, let bodyEncoding, let urlParameters):
            XCTAssertTrue(bodyEncoding is JSONEncoding, "Body encoding should be JSON")
            XCTAssertEqual(bodyParameters["b"] as? String, "bodyVal")
            XCTAssertEqual(urlParameters["q"] as? String, "queryVal")
        default:
            XCTFail("Expected requestCompositeParameters, got \(target.task)")
        }
    }
    
    func testInvalidEncodingStringThrowsConfigError() {
        let config = APIConfig(
            version: "1.0",
            globals: GlobalsConfig(baseURL: "https://api.example.com"),
            operations: [
                "invalid_enc": OperationConfig(
                    path: "/test",
                    method: "POST",
                    encoding: "foobar"
                )
            ]
        )
        
        XCTAssertThrowsError(try DynamicTarget(config: config, endpointName: "invalid_enc", runtimeParams: [:])) { error in
            guard let err = error as? DynamicAPIError, case .configurationError(let reason) = err else {
                XCTFail("Should throw configurationError")
                return
            }
            XCTAssertTrue(reason.contains("invalid encoding"), "Error should mention invalid encoding")
        }
    }
    
    func testGetWithJsonEncodingStillUsesUrlParametersOrFails() {
        let config = APIConfig(
            version: "1.0",
            globals: GlobalsConfig(baseURL: "https://api.example.com"),
            operations: [
                "get_json": OperationConfig(
                    path: "/get",
                    method: "GET",
                    encoding: "json"
                )
            ]
        )
        
        // We decided to disallow GET + JSON encoding in strict mode
        XCTAssertThrowsError(try DynamicTarget(config: config, endpointName: "get_json", runtimeParams: [:])) { error in
            guard let err = error as? DynamicAPIError, case .configurationError(let reason) = err else {
                XCTFail("Should throw configurationError")
                return
            }
            XCTAssertTrue(reason.contains("GET but has encoding 'json'"), "Error should mention GET encoding restriction")
        }
    }
}

private extension OperationConfig {
    init(path: String, method: String, params: [String: AnyCodable]? = nil, body: AnyCodable? = nil, encoding: String? = nil) {
        self.init(path: path, method: method, headers: nil, params: params, body: body, responseMapping: nil, usePresets: nil, taskType: nil, encoding: encoding, processors: nil)
    }
}
