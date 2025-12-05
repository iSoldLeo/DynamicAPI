import XCTest
import Moya
@testable import DynamicAPI

final class EncodingBehaviorTests: XCTestCase {
    
    func testJSONEncoding() throws {
        let config = APIConfig(
            version: "1.0",
            globals: GlobalsConfig(baseURL: "https://api.example.com"),
            operations: [
                "create_user": OperationConfig(
                    path: "/users",
                    method: "POST",
                    params: ["name": AnyCodable("$name")],
                    encoding: "json"
                )
            ]
        )
        
        let target = try DynamicTarget(
            config: config,
            endpointName: "create_user",
            runtimeParams: ["name": "Alice"]
        )
        
        switch target.task {
        case .requestParameters(let params, let encoding):
            XCTAssertTrue(encoding is JSONEncoding, "Should use JSONEncoding for 'json' config")
            XCTAssertEqual(params["name"] as? String, "Alice")
        default:
            XCTFail("Expected requestParameters task")
        }
    }
    
    func testURLEncoding() throws {
        let config = APIConfig(
            version: "1.0",
            globals: GlobalsConfig(baseURL: "https://api.example.com"),
            operations: [
                "search": OperationConfig(
                    path: "/search",
                    method: "GET",
                    params: ["q": AnyCodable("$q")],
                    encoding: "url"
                )
            ]
        )
        
        let target = try DynamicTarget(
            config: config,
            endpointName: "search",
            runtimeParams: ["q": "swift"]
        )
        
        switch target.task {
        case .requestParameters(let params, let encoding):
            XCTAssertTrue(encoding is URLEncoding, "Should use URLEncoding for 'url' config")
            XCTAssertEqual(params["q"] as? String, "swift")
        default:
            XCTFail("Expected requestParameters task")
        }
    }
    
    func testDefaultEncoding() throws {
        let config = APIConfig(
            version: "1.0",
            globals: GlobalsConfig(baseURL: "https://api.example.com"),
            operations: [
                "default_get": OperationConfig(
                    path: "/get",
                    method: "GET",
                    params: ["id": AnyCodable("1")],
                    encoding: nil
                )
            ]
        )
        
        let target = try DynamicTarget(
            config: config,
            endpointName: "default_get",
            runtimeParams: [:]
        )
        
        switch target.task {
        case .requestParameters(_, let encoding):
            XCTAssertTrue(encoding is URLEncoding)
        default:
            XCTFail("Expected requestParameters")
        }
    }
}

extension APIConfig {
    init(version: String? = nil, globals: GlobalsConfig, operations: [String: OperationConfig]) {
        self.init(version: version, globals: globals, profiles: nil, operations: operations, paramPresets: nil)
    }
}

extension GlobalsConfig {
    init(baseURL: String) {
        self.init(baseURL: baseURL, headers: nil, timeout: nil)
    }
}

private extension OperationConfig {
    init(path: String, method: String, params: [String: AnyCodable]? = nil, encoding: String? = nil) {
        self.init(path: path, method: method, headers: nil, params: params, body: nil, responseMapping: nil, usePresets: nil, taskType: nil, encoding: encoding, processors: nil)
    }
}
