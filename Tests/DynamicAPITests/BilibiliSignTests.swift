import XCTest
@testable import DynamicAPI
import Moya
import CommonCrypto

// MARK: - Mock Signer

struct BilibiliAppSigner: RequestProcessor {
    let appSecret: String
    
    func process(params: inout [String: Any], headers: inout [String: String], operation: ResolvedOperation, runtimeValues: [String: Any]) throws {
        // 1. Sort keys
        let sortedKeys = params.keys.sorted()
        
        // 2. Build string
        var paramString = ""
        for key in sortedKeys {
            if let value = params[key] {
                if !paramString.isEmpty {
                    paramString += "&"
                }
                paramString += "\(key)=\(value)"
            }
        }
        
        // 3. Append Secret
        let stringToSign = paramString + appSecret
        
        // 4. MD5 (Mock implementation for test simplicity, or use CommonCrypto)
        // Since we can't easily import CommonCrypto in a pure Swift package without bridging header in some envs,
        // we will just append "_signed" for verification if MD5 is hard.
        // But let's try to do a simple hash or just a marker.
        // For this test, we just want to verify the processor modified the params.
        
        let sign = "signed_\(stringToSign.count)" // Mock signature
        
        // 5. Inject sign
        params["sign"] = sign
        
        // Also inject a header for verification
        headers["X-Bili-Sign-Debug"] = "true"
    }
}

final class BilibiliSignTests: XCTestCase {
    
    var client: DynamicAPIClient!
    
    override func setUpWithError() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "bilibili_app_config", withExtension: "json") else {
            XCTFail("Missing bilibili_app_config.json")
            return
        }
        let loader = try ConfigLoader.load(from: url)
        
        // Use a provider that records the request so we can inspect it
        let provider = MoyaProvider<DynamicTarget>(stubClosure: MoyaProvider.immediatelyStub)
        client = DynamicAPIClient(configLoader: loader, provider: provider)
        
        // Register Processor
        client.register(processor: BilibiliAppSigner(appSecret: "FAKE_SECRET"), for: "BilibiliAppSigner")
    }
    
    func testAppSearchSigning() async throws {
        // We expect the processor to add 'sign' parameter
        
        // Since we are using stubClosure, the request won't actually go out, 
        // but Moya's stubbing mechanism usually returns sampleData.
        // We need to inspect the *Target* that was created.
        // But client.call() returns the result.
        
        // To verify the request parameters, we can use a custom EndpointClosure in MoyaProvider
        // or just trust that if the logic in client.call executes, the target will have the params.
        
        // Let's use a trick: The DynamicTarget is created inside call().
        // We can't easily inspect it from outside without mocking the Provider more deeply.
        
        // However, we can verify the logic by checking if the processor was called?
        // Or we can rely on the fact that we modified the `DynamicAPIClient` to use the processor.
        
        // Let's try to capture the request using a custom plugin for Moya.
        
        let expectation = XCTestExpectation(description: "Request sent with signature")
        
        _ = NetworkLoggerPlugin(configuration: .init(logOptions: .verbose))
        // NetworkLoggerPlugin logs to console, doesn't help us assert.
        
        // Custom Plugin to capture target
        struct CapturingPlugin: PluginType {
            let onPrepare: (URLRequest) -> Void
            
            func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
                onPrepare(request)
                return request
            }
        }
        
        let plugin = CapturingPlugin { request in
            guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return
            }
            
            let queryItems = components.queryItems ?? []
            let signItem = queryItems.first(where: { $0.name == "sign" })
            
            if let sign = signItem?.value, sign.starts(with: "signed_") {
                expectation.fulfill()
            }
            
            // Verify header
            if request.allHTTPHeaderFields?["X-Bili-Sign-Debug"] == "true" {
                // Good
            }
        }
        
        // Re-init client with plugin
        let bundle = Bundle.module
        let url = bundle.url(forResource: "bilibili_app_config", withExtension: "json")!
        let loader = try ConfigLoader.load(from: url)
        let provider = MoyaProvider<DynamicTarget>(stubClosure: MoyaProvider.immediatelyStub, plugins: [plugin])
        client = DynamicAPIClient(configLoader: loader, provider: provider)
        client.register(processor: BilibiliAppSigner(appSecret: "FAKE_SECRET"), for: "BilibiliAppSigner")
        
        // Call
        // We don't care about the response (it will be empty sampleData), we care about the request preparation
        try? await client.call("app_search", params: ["keyword": "swift"])
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
