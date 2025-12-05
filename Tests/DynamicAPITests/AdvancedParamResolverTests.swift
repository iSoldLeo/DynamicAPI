import XCTest
@testable import DynamicAPI

final class AdvancedParamResolverTests: XCTestCase {
    
    func testMissingParameterStrictness() {
        let template = ["key": "$missing"]
        let runtimeValues: [String: Any] = [:]
        
        XCTAssertThrowsError(try ParamResolver.resolve(templates: template, runtimeValues: runtimeValues)) { error in
            guard let err = error as? DynamicAPIError, case .parameterError(let reason, let param) = err else {
                XCTFail("Should throw parameterError")
                return
            }
            XCTAssertEqual(param, "missing")
            XCTAssertTrue(reason.contains("Missing required parameter"))
        }
    }
    
    func testNoImplicitConversion() throws {
        // Template expects String (implied by usage in URL or just by being a value), 
        // but if we pass Int, it should remain Int in the resolved dictionary if it's Any.
        // But if the template was a String "$val", and runtime is Int 123.
        // The resolved value should be Int(123), not String("123").
        
        let template: [String: Any] = ["id": "$id"]
        let runtimeValues: [String: Any] = ["id": 123]
        
        let resolved = try ParamResolver.resolve(templates: template, runtimeValues: runtimeValues)
        
        XCTAssertTrue(resolved["id"] is Int, "Should preserve Int type")
        XCTAssertEqual(resolved["id"] as? Int, 123)
        
        // If we have a string template that is NOT a placeholder, it stays string.
        let template2: [String: Any] = ["fixed": "123"]
        let resolved2 = try ParamResolver.resolve(templates: template2, runtimeValues: runtimeValues)
        XCTAssertTrue(resolved2["fixed"] is String, "Should preserve String type")
    }
    
    func testEscaping() throws {
        // $$ should become $
        let template: [String: Any] = ["price": "$$100"]
        let runtimeValues: [String: Any] = [:]
        
        let resolved = try ParamResolver.resolve(templates: template, runtimeValues: runtimeValues)
        
        XCTAssertEqual(resolved["price"] as? String, "$100")
    }
    
    func testRecursiveResolution() throws {
        let template: [String: Any] = [
            "meta": [
                "user_id": "$uid",
                "tags": ["$tag1", "fixed"]
            ]
        ]
        let runtimeValues: [String: Any] = ["uid": 999, "tag1": "swift"]
        
        let resolved = try ParamResolver.resolve(templates: template, runtimeValues: runtimeValues)
        
        guard let meta = resolved["meta"] as? [String: Any] else {
            XCTFail("Meta should be dict")
            return
        }
        
        XCTAssertEqual(meta["user_id"] as? Int, 999)
        
        guard let tags = meta["tags"] as? [Any] else {
            XCTFail("Tags should be array")
            return
        }
        
        XCTAssertEqual(tags[0] as? String, "swift")
        XCTAssertEqual(tags[1] as? String, "fixed")
    }
    
    func testEscapedDollarReturnsLiteralString() throws {
        let template: [String: Any] = ["key": "$$value"]
        let runtimeValues: [String: Any] = [:]
        
        let resolved = try ParamResolver.resolve(templates: template, runtimeValues: runtimeValues)
        
        XCTAssertEqual(resolved["key"] as? String, "$value")
    }
    
    func testMissingPlaceholderThrowsParameterErrorWithName() {
        let template: [String: Any] = ["userId": "$user_id"]
        let runtimeValues: [String: Any] = [:]
        
        XCTAssertThrowsError(try ParamResolver.resolve(templates: template, runtimeValues: runtimeValues)) { error in
            guard let err = error as? DynamicAPIError, case .parameterError(_, let param) = err else {
                XCTFail("Should throw parameterError")
                return
            }
            XCTAssertEqual(param, "user_id")
        }
    }
    
    func testNestedDictionaryAndArrayPlaceholdersAreResolved() throws {
        let template: [String: Any] = [
            "filter": [
                "keywords": ["$kw1", "$kw2"],
                "range": ["min": "$min", "max": "$max"]
            ]
        ]
        let runtimeValues: [String: Any] = ["kw1": "a", "kw2": "b", "min": 1, "max": 10]
        
        let resolved = try ParamResolver.resolve(templates: template, runtimeValues: runtimeValues)
        
        guard let filter = resolved["filter"] as? [String: Any],
              let keywords = filter["keywords"] as? [Any],
              let range = filter["range"] as? [String: Any] else {
            XCTFail("Structure mismatch")
            return
        }
        
        XCTAssertEqual(keywords[0] as? String, "a")
        XCTAssertEqual(keywords[1] as? String, "b")
        XCTAssertEqual(range["min"] as? Int, 1)
        XCTAssertEqual(range["max"] as? Int, 10)
    }
    
    func testAnyCodableWrapperIsUnwrappedAndResolved() throws {
        let template: [String: Any] = ["id": AnyCodable("$id")]
        let runtimeValues: [String: Any] = ["id": 42]
        
        let resolved = try ParamResolver.resolve(templates: template, runtimeValues: runtimeValues)
        
        XCTAssertEqual(resolved["id"] as? Int, 42)
    }
    
    func testStringWithoutLeadingDollarIsNotTreatedAsPlaceholder() throws {
        let template: [String: Any] = ["text": "user_$id"]
        let runtimeValues: [String: Any] = ["id": "123"]
        
        let resolved = try ParamResolver.resolve(templates: template, runtimeValues: runtimeValues)
        
        XCTAssertEqual(resolved["text"] as? String, "user_$id")
    }
}
