import XCTest
@testable import DynamicAPI
import Moya

final class DownloadTests: XCTestCase {
    var client: DynamicAPIClient!
    
    override func setUpWithError() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "download_config", withExtension: "json") else {
            XCTFail("Missing download_config.json")
            return
        }
        let loader = try ConfigLoader.load(from: url)
        let provider = MoyaProvider<DynamicTarget>()
        client = DynamicAPIClient(configLoader: loader, provider: provider)
    }
    
    func testDownloadImage() async throws {
        // Skip in CI/standard runs to avoid network dependency
        try XCTSkipIf(ProcessInfo.processInfo.environment["ENABLE_DOWNLOAD_TEST"] == nil, "Skipping Download integration test. Set ENABLE_DOWNLOAD_TEST=1 to run.")

        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("test_image.png")
        // Clean up before test
        try? FileManager.default.removeItem(at: destination)
        
        print("Downloading to: \(destination.path)")
        
        let url = try await client.download("download_image", destination: destination)
        
        XCTAssertEqual(url, destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 0)
        
        print("Downloaded file size: \(fileSize) bytes")
        
        // Clean up
        try? FileManager.default.removeItem(at: destination)
    }

    func testDownloadFailure() async throws {
        // Use a stub provider to simulate failure
        let stubProvider = MoyaProvider<DynamicTarget>(endpointClosure: { target in
            return Endpoint(
                url: URL(target: target).absoluteString,
                sampleResponseClosure: { .networkResponse(404, Data()) },
                method: target.method,
                task: target.task,
                httpHeaderFields: target.headers
            )
        }, stubClosure: MoyaProvider.immediatelyStub)
        
        let stubClient = DynamicAPIClient(configLoader: client.configLoader, provider: stubProvider)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("fail_download.png")
        
        do {
            _ = try await stubClient.download("download_image", destination: destination)
            XCTFail("Should have thrown error")
        } catch let error as DynamicAPIError {
            if case .networkError(let moyaError) = error, case .statusCode(let response) = moyaError {
                XCTAssertEqual(response.statusCode, 404)
            } else {
                XCTFail("Incorrect error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
