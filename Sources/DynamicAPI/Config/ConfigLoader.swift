import Foundation
import Moya
import os.log

public class ConfigLoader: @unchecked Sendable {
    public let config: APIConfig
    
    private var _currentProfile: String?
    private let queue = DispatchQueue(label: "com.dynamicapi.configloader.profile", attributes: .concurrent)
    
    public var currentProfile: String? {
        get {
            queue.sync {
                return _currentProfile
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._currentProfile = newValue
            }
        }
    }
    
    public init(config: APIConfig, profile: String? = nil) {
        self.config = config
        self._currentProfile = profile
    }
    
    public static func load(from url: URL) throws -> ConfigLoader {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let config = try decoder.decode(APIConfig.self, from: data)
        try config.validate()
        return ConfigLoader(config: config)
    }
    
    public static func load(from data: Data) throws -> ConfigLoader {
        let decoder = JSONDecoder()
        let config = try decoder.decode(APIConfig.self, from: data)
        try config.validate()
        return ConfigLoader(config: config)
    }
    
    private let headerBlacklist: Set<String> = ["host", "content-length", "accept-encoding", "connection", "upgrade"]
    
    public func resolve(operation name: String) throws -> ResolvedOperation {
        os_log("🔍 Resolving Config for: %{public}@", log: DynamicAPILogger.config, type: .debug, name)
        guard let opConfig = config.operations[name] else {
            os_log("❌ Operation not found: %{public}@", log: DynamicAPILogger.config, type: .error, name)
            throw DynamicAPIError.configurationError(reason: "Operation '\(name)' not found")
        }
        
        // 验证操作配置
        try opConfig.validate(name: name, presets: config.paramPresets)
        
        // 验证路径（防止通过配置进行域名劫持）
        if opConfig.path.contains("://") || opConfig.path.hasPrefix("//") {
             os_log("❌ Security Warning: Absolute URL or Scheme-Relative URL detected in path: %{public}@", log: DynamicAPILogger.config, type: .fault, opConfig.path)
             throw DynamicAPIError.configurationError(reason: "Security Violation: Absolute path not allowed in operation config")
        }
        
        // 1. 从全局配置开始
        var baseURLString = config.globals.baseURL
        var headers = config.globals.headers ?? [:]
        
        // 2. 应用 Profile 覆盖
        if let profileName = currentProfile, let profiles = config.profiles, let profile = profiles[profileName] {
            os_log("👤 Applying Profile: %{public}@", log: DynamicAPILogger.config, type: .info, profileName)
            if let profileBaseURL = profile.baseURL {
                baseURLString = profileBaseURL
            }
            if let profileHeaders = profile.headers {
                headers.merge(profileHeaders) { (_, new) in new }
            }
        }
        
        // 3. 应用操作覆盖
        if let opHeaders = opConfig.headers {
            headers.merge(opHeaders) { (_, new) in new }
        }
        
        // 过滤黑名单 Headers
        let filteredHeaders = headers.filter { (key, _) in
            !headerBlacklist.contains(key.lowercased())
        }
        if filteredHeaders.count < headers.count {
            os_log("⚠️ Security Warning: Some headers were ignored due to blacklist.", log: DynamicAPILogger.config, type: .default)
        }
        headers = filteredHeaders
        
        guard let baseURL = URL(string: baseURLString) else {
            os_log("❌ Invalid Base URL: %{public}@", log: DynamicAPILogger.config, type: .error, baseURLString)
            throw DynamicAPIError.configurationError(reason: "Invalid Base URL: \(baseURLString)")
        }
        
        // 解析参数（包括预设）
        var params = [String: Any]()
        
        // 应用预设（如果有）
        if let presetNames = opConfig.usePresets, let allPresets = config.paramPresets {
            for presetName in presetNames {
                if let presetParams = allPresets[presetName] {
                    params.merge(presetParams) { (_, new) in new }
                }
            }
        }
        
        // Apply operation params
        if let opParams = opConfig.params {
            // Convert AnyCodable to Any
            let unwrappedParams = opParams.mapValues { $0.value }
            params.merge(unwrappedParams) { (_, new) in new }
        }
        
        let method = Moya.Method(rawValue: opConfig.method.uppercased())
        
        os_log("🔧 Config Resolved: %{public}@ %{public}@%{public}@", log: DynamicAPILogger.config, type: .debug, "\(method)", baseURL.absoluteString, opConfig.path)
        return ResolvedOperation(
            baseURL: baseURL,
            path: opConfig.path,
            method: method,
            headers: headers,
            params: params,
            body: opConfig.body?.value,
            responseMapping: opConfig.responseMapping,
            taskType: opConfig.taskType,
            encoding: opConfig.encoding,
            processors: opConfig.processors
        )
    }
}
