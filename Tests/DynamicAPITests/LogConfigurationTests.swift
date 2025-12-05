import XCTest
@testable import DynamicAPI
import os.log

final class LogConfigurationTests: XCTestCase {
    
    override func tearDown() {
        // Reset to default
        DynamicAPILogger.configuration.level = .info
        DynamicAPILogger.configuration.subsystem = "com.dynamicapi"
    }
    
    func testLogLevelConfiguration() {
        // 1. Set to .none
        DynamicAPILogger.configuration.level = .none
        XCTAssertEqual(DynamicAPILogger.configuration.level, .none)
        
        // We can't easily assert that nothing was logged to OSLog without private APIs,
        // but we can assert that the configuration was accepted.
        
        // 2. Set to .debug
        DynamicAPILogger.configuration.level = .debug
        XCTAssertEqual(DynamicAPILogger.configuration.level, .debug)
    }
    
    func testSubsystemConfiguration() {
        DynamicAPILogger.configuration.subsystem = "com.example.myapp"
        XCTAssertEqual(DynamicAPILogger.configuration.subsystem, "com.example.myapp")
        
        // Verify that new loggers use this subsystem (implementation detail check)
        let clientLog = DynamicAPILogger.client
        // In a real black-box test we might not be able to check the internal OSLog object's subsystem easily
        // unless we expose it. Assuming DynamicAPILogger exposes `client` which is `OSLog`.
        // OSLog properties are not easily inspectable in Swift.
        // So we rely on the public API setting.
    }
    
    func testPerformanceOptimization() {
        // Verify that when log level is .none, we don't execute closures (if we had a closure based API)
        // Since we use os_log directly in the implementation, we are testing if our wrapper (if we add one) works.
        // If we stick to os_log, we trust Apple.
        // But if we add `DynamicAPILogger.log(...)`, we can test it.
        
        // Let's assume we will add a wrapper `DynamicAPILogger.log(level: ...)` to support the level filtering.
        
        var closureCalled = false
        DynamicAPILogger.configuration.level = .none
        
        DynamicAPILogger.log(level: .info, "Test") {
            closureCalled = true
            return "Computed Message"
        }
        
        XCTAssertFalse(closureCalled, "Closure should not be called when log level is none")
    }
    
    func testLogLevelFiltering() {
        // 1. Level = .error, calling .info -> closure not executed
        DynamicAPILogger.configuration.level = .error
        var closureCalled = false
        DynamicAPILogger.log(level: .info, "Test") {
            closureCalled = true
            return "Computed Message"
        }
        XCTAssertFalse(closureCalled, "Closure should not be called when log level is error and we log info")
        
        // 2. Level = .debug, calling .info -> closure executed
        DynamicAPILogger.configuration.level = .debug
        closureCalled = false
        DynamicAPILogger.log(level: .info, "Test") {
            closureCalled = true
            return "Computed Message"
        }
        XCTAssertTrue(closureCalled, "Closure should be called when log level is debug and we log info")
    }
}
