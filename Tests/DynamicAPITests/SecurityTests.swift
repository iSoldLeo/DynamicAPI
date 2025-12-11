import XCTest
@testable import DynamicAPI
import Moya

final class SecurityTests: XCTestCase {
    
    var loader: ConfigLoader!
    var client: DynamicAPIClient!
    
    override func setUpWithError() throws {
        // Create a secure config
        let json = """
        {
            "version": "1.0",
            "globals": {
                "base_url": "https://api.example.com",
                "headers": {
                    "X-App-Version": "1.0"
                }
            },
            "profiles": {},
            "operations": {
                "safe_op": {
                    "path": "/safe",
                    "method": "GET"
                },
                "header_injection": {
                    "path": "/headers",
                    "method": "GET",
                    "headers": {
                        "Host": "evil.com",
                        "Content-Length": "0",
                        "X-Custom": "Allowed"
                    }
                },
                "path_traversal_config": {
                    "path": "//evil.com/hack",
                    "method": "GET"
                },
                "path_param_injection": {
                    "path": "/files/$filename",
                    "method": "GET"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        loader = try ConfigLoader.load(from: data)
        
        let provider = MoyaProvider<DynamicTarget>(stubClosure: MoyaProvider.immediatelyStub)
        client = DynamicAPIClient(configLoader: loader, provider: provider)
    }
    
    // 3. Header Blacklist Test
    func testHeaderBlacklist() throws {
        let operation = try loader.resolve(operation: "header_injection")
        
        // Host and Content-Length should be removed
        XCTAssertNil(operation.headers["Host"])
        XCTAssertNil(operation.headers["Content-Length"])
        
        // Allowed headers should remain
        XCTAssertEqual(operation.headers["X-Custom"], "Allowed")
        XCTAssertEqual(operation.headers["X-App-Version"], "1.0")
    }
    
    // 2. Path Traversal in Config Test
    func testConfigPathTraversal() {
        XCTAssertThrowsError(try loader.resolve(operation: "path_traversal_config")) { error in
            guard let dynamicError = error as? DynamicAPIError,
                  case .configurationError(let reason) = dynamicError else {
                XCTFail("Unexpected error type")
                return
            }
            XCTAssertTrue(reason.contains("Security Violation"))
        }
    }
    
    // 2. Path Traversal in Params Test
    func testParamPathTraversal() async throws {
        // Injecting ../ into a path parameter
        // Should be encoded to %2E%2E%2F
        let params = ["filename": "../../etc/passwd"]
        
        // We need to inspect the resolved URL.
        // We can do this by resolving the target manually.
        let operation = try loader.resolve(operation: "path_param_injection")
        let target = try DynamicTarget(operation: operation, runtimeValues: params)
        
        let url = URL(target: target)
        print("Resolved URL: \(url.absoluteString)")
        
        // Verify it didn't traverse
        // The URL encoding might happen twice (once by ParamResolver, once by Moya/URL), 
        // resulting in %252F instead of %2F. This is safe as it prevents traversal.
        // We just want to ensure the raw path separators are NOT present.
        
        let absoluteString = url.absoluteString
        XCTAssertFalse(absoluteString.contains("../"))
        XCTAssertTrue(absoluteString.contains("..%2F") || absoluteString.contains("..%252F"))
    }

    func testQueryParamInjection() async throws {
        // Injecting a URL into a query parameter
        // Should be encoded and not affect the host/path
        _ = ["q": "https://evil.com"]
        
        // Assuming we have an operation with query params. 
        // "header_injection" has no params defined in the inline config above.
        // Let's add one or use "safe_op" if we can inject params (DynamicTarget might ignore extra params if not defined).
        // The inline config for "safe_op" doesn't have params.
        // We need to update the inline config in setUpWithError to include an operation with params.
        // Or we can just test that if we pass it, it doesn't change the URL structure if it were used.
        // But DynamicTarget filters params.
        
        // Let's update the inline config in setUpWithError first? No, I can't easily update setUpWithError without replacing the whole file content or a large chunk.
        // I'll check if I can use "path_param_injection" which has a path param.
        // But I want query param.
        
        // I will add a new test case that creates its own loader with a config that has query params.
        
        let json = """
        {
            "version": "1.0",
            "globals": { "base_url": "https://api.example.com" },
            "operations": {
                "search": {
                    "path": "/search",
                    "method": "GET",
                    "params": { "q": "$query" }
                }
            }
        }
        """
        let localLoader = try ConfigLoader.load(from: json.data(using: .utf8)!)
        let operation = try localLoader.resolve(operation: "search")
        let target = try DynamicTarget(operation: operation, runtimeValues: ["query": "https://evil.com"])
        
        // Manually construct URL to verify query params
        var components = URLComponents(url: target.baseURL.appendingPathComponent(target.path), resolvingAgainstBaseURL: false)!
        if case .requestParameters(let params, _) = target.task {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        }
        
        let absoluteString = components.url!.absoluteString
        print("DEBUG: Query Param Injection URL: \(absoluteString)")
        
        XCTAssertTrue(absoluteString.starts(with: "https://api.example.com/search"))
        // Check for presence of the value, allowing for different encoding strategies
        // We mainly want to ensure it's NOT treated as a new host
        XCTAssertTrue(absoluteString.contains("evil.com"))
        XCTAssertTrue(absoluteString.contains("q="))
        
        // But definitely should not change the host
        XCTAssertEqual(components.url!.host, "api.example.com")
    }
    
    // 2. Domain Injection in Params Test
    func testParamDomainInjection() async throws {
        // Injecting a full URL into a path parameter
        let params = ["filename": "https://evil.com"]
        
        let operation = try loader.resolve(operation: "path_param_injection")
        let target = try DynamicTarget(operation: operation, runtimeValues: params)
        
        let url = URL(target: target)
        print("Resolved URL: \(url.absoluteString)")
        
        // Should be encoded
        // https:// becomes https:%2F%2F or https:%252F%252F
        XCTAssertFalse(url.absoluteString.contains("//evil.com"), "Should not contain raw //evil.com")
        XCTAssertTrue(url.absoluteString.contains("evil.com"))
        
        // Should still be on original domain
        XCTAssertTrue(url.absoluteString.hasPrefix("https://api.example.com"))
    }
}
