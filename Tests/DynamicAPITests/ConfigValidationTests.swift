import XCTest
@testable import DynamicAPI

final class ConfigValidationTests: XCTestCase {
    
    func testInvalidEncoding() throws {
        let bundle = Bundle.module
        // Try finding it at root first (flattened)
        guard let url = bundle.url(forResource: "invalid_encoding", withExtension: "json") ?? 
                        bundle.url(forResource: "invalid_encoding", withExtension: "json", subdirectory: "Validation") else {
            XCTFail("Missing invalid_encoding.json")
            return
        }
        
        // Should throw configurationError because "magic_encoding" is not valid
        XCTAssertThrowsError(try ConfigLoader.load(from: url)) { error in
            guard let err = error as? DynamicAPIError, case .configurationError(let reason) = err else {
                XCTFail("Should throw configurationError")
                return
            }
            XCTAssertTrue(reason.lowercased().contains("invalid encoding"), "Error should mention invalid encoding")
        }
    }
    
    func testMissingPreset() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "missing_preset", withExtension: "json") ??
                        bundle.url(forResource: "missing_preset", withExtension: "json", subdirectory: "Validation") else {
            XCTFail("Missing missing_preset.json")
            return
        }
        
        // Should throw configurationError because preset doesn't exist
        XCTAssertThrowsError(try ConfigLoader.load(from: url)) { error in
            guard let err = error as? DynamicAPIError, case .configurationError(let reason) = err else {
                XCTFail("Should throw configurationError")
                return
            }
            XCTAssertTrue(reason.contains("missing preset"), "Error should mention missing preset")
        }
    }
    
    func testGetWithBody() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "get_with_body", withExtension: "json") ??
                        bundle.url(forResource: "get_with_body", withExtension: "json", subdirectory: "Validation") else {
            XCTFail("Missing get_with_body.json")
            return
        }
        
        XCTAssertThrowsError(try ConfigLoader.load(from: url)) { error in
            guard let err = error as? DynamicAPIError, case .configurationError(let reason) = err else {
                XCTFail("Should throw configurationError")
                return
            }
            XCTAssertTrue(reason.contains("GET but has a body"), "Error should mention GET body issue")
        }
    }
}
