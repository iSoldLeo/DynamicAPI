import XCTest
import Moya
@testable import DynamicAPI

final class DynamicAPIErrorTests: XCTestCase {
    
    func testConfigurationErrorDescriptionContainsReason() {
        let error = DynamicAPIError.configurationError(reason: "Missing endpoint 'foo'")
        XCTAssertTrue(error.localizedDescription.contains("Configuration Error:"))
        XCTAssertTrue(error.localizedDescription.contains("Missing endpoint 'foo'"))
    }
    
    func testParameterErrorIncludesParameterNameInDescription() {
        let error = DynamicAPIError.parameterError(reason: "Missing required parameter", parameter: "user_id")
        XCTAssertTrue(error.localizedDescription.contains("Parameter Error"))
        XCTAssertTrue(error.localizedDescription.contains("user_id"))
    }
    
    func testParameterErrorWithoutParameterOmitsParameterPart() {
        let error = DynamicAPIError.parameterError(reason: "Invalid value", parameter: nil)
        XCTAssertTrue(error.localizedDescription.contains("Parameter Error"))
        XCTAssertFalse(error.localizedDescription.contains("(Parameter:"))
    }
    
    func testNetworkErrorWrapsMoyaError() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad url"])
        let moyaError = MoyaError.underlying(underlying, nil)
        let error = DynamicAPIError.networkError(originalError: moyaError)
        XCTAssertTrue(error.localizedDescription.contains("Network Error"))
        XCTAssertTrue(error.localizedDescription.contains("bad url"))
    }
    
    func testMappingErrorWithAndWithoutOriginalError() {
        let error1 = DynamicAPIError.mappingError(reason: "Bad JSON", originalError: nil)
        XCTAssertTrue(error1.localizedDescription.contains("Mapping Error: Bad JSON"))
        
        struct DummyError: Error, LocalizedError {
            var errorDescription: String? { return "Underlying issue" }
        }
        
        let error2 = DynamicAPIError.mappingError(reason: "Bad JSON", originalError: DummyError())
        XCTAssertTrue(error2.localizedDescription.contains("Mapping Error: Bad JSON"))
        XCTAssertTrue(error2.localizedDescription.contains("Underlying issue"))
    }
    
    func testUnknownErrorDescriptionUsesUnderlyingDescription() {
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? { return "Something weird happened" }
        }
        let error = DynamicAPIError.unknownError(originalError: CustomError())
        XCTAssertTrue(error.localizedDescription.contains("Unknown Error"))
        XCTAssertTrue(error.localizedDescription.contains("Something weird happened"))
    }
    
    func testDynamicAPIErrorIsLocalizedError() {
        let error = DynamicAPIError.configurationError(reason: "test")
        XCTAssertNotNil(error.errorDescription)
    }
}
