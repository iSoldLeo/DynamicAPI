import Foundation
import os.log

public struct DynamicAPILogger {
    public enum LogLevel: Int, Comparable, Sendable {
        case none = 0
        case error = 1
        case warning = 2
        case info = 3
        case debug = 4
        
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    public struct Configuration: Sendable {
        public var level: LogLevel = .info
        public var subsystem: String = "com.dynamicapi"
    }
    
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _configuration = Configuration()
    
    public static var configuration: Configuration {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _configuration
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _configuration = newValue
        }
    }
    
    // 日志分类
    public static var client: OSLog { OSLog(subsystem: configuration.subsystem, category: "Client") }
    public static var config: OSLog { OSLog(subsystem: configuration.subsystem, category: "Config") }
    public static var runtime: OSLog { OSLog(subsystem: configuration.subsystem, category: "Runtime") }
    
    public static func log(level: LogLevel, category: OSLog = client, _ message: String, _ details: (() -> String)? = nil) {
        guard level.rawValue <= configuration.level.rawValue, configuration.level != .none else { return }
        
        let detailStr = details?() ?? ""
        let fullMessage = detailStr.isEmpty ? message : "\(message) - \(detailStr)"
        
        let type: OSLogType
        switch level {
        case .none: return
        case .error: type = .error
        case .warning: type = .fault
        case .info: type = .info
        case .debug: type = .debug
        }
        
        os_log("%{public}@", log: category, type: type, fullMessage)
    }
}
