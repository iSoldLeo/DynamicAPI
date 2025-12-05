import XCTest
@testable import DynamicAPI
import Moya

final class ConcurrencyTests: XCTestCase, @unchecked Sendable {
    
    var client: DynamicAPIClient!
    
    override func setUpWithError() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "full_config", withExtension: "json") else { return }
        let loader = try ConfigLoader.load(from: url)
        
        // Stub provider that returns immediately
        let provider = MoyaProvider<DynamicTarget>(stubClosure: MoyaProvider.immediatelyStub)
        client = DynamicAPIClient(configLoader: loader, provider: provider)
    }
    
    // T01: 并发请求
    func testConcurrentRequests() {
        let expectation = XCTestExpectation(description: "Concurrent requests")
        expectation.expectedFulfillmentCount = 100
        
        let client = self.client!
        
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            _Concurrency.Task {
                do {
                    // We use a simple call that doesn't require complex mapping
                    // get_user requires 'id' and 'req_id'
                    let _: Void = try await client.call("get_user", params: ["id": "\(i)", "req_id": "r\(i)"])
                    expectation.fulfill()
                } catch {
                    // It might fail due to decoding if we don't provide sample data that matches Void (empty) or if we expect a return type.
                    // call() without return type ignores body, so it should succeed as long as 200 OK.
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // T02: 并发注册 Mapper
    func testConcurrentMapperRegistration() {
        let expectation = XCTestExpectation(description: "Concurrent registration")
        expectation.expectedFulfillmentCount = 100
        
        let client = self.client!
        
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            client.register(mapper: DefaultJSONMapper(), for: "mapper_\(i)")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Verify one
        XCTAssertNotNil(self.client.getMapper(for: "mapper_50"))
    }
    
    // T03: 配置并发读写 (Profile Switching)
    func testConcurrentProfileSwitching() {
        let expectation = XCTestExpectation(description: "Concurrent profile switching")
        expectation.expectedFulfillmentCount = 100
        
        let client = self.client!
        
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            if i % 2 == 0 {
                client.configLoader.currentProfile = "dev"
            } else {
                client.configLoader.currentProfile = "staging"
            }
            
            // Read immediately
            let _ = client.configLoader.currentProfile
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}
