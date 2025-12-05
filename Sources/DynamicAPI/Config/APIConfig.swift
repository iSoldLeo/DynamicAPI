import Foundation

public struct APIConfig: Codable {
    public let version: String?
    public let globals: GlobalsConfig
    public let profiles: [String: ProfileConfig]?
    public let operations: [String: OperationConfig]
    public let paramPresets: [String: [String: String]]?
    
    enum CodingKeys: String, CodingKey {
        case version
        case globals
        case profiles
        case operations
        case paramPresets = "param_presets"
    }
}

public struct GlobalsConfig: Codable {
    public let baseURL: String
    public let headers: [String: String]?
    public let timeout: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case headers
        case timeout
    }
}

public struct ProfileConfig: Codable {
    public let baseURL: String?
    public let headers: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case headers
    }
}

public struct OperationConfig: Codable {
    public let path: String
    public let method: String
    public let headers: [String: String]?
    public let params: [String: AnyCodable]? // Key: 值 或 $占位符
    public let body: AnyCodable? // 用于 POST/PUT
    public let responseMapping: String?
    public let usePresets: [String]?
    public let taskType: String? // "request" (默认), "download", "upload"
    public let encoding: String? // "json", "url", "form"
    public let processors: [String]? // List of processor names to apply
    
    enum CodingKeys: String, CodingKey {
        case path
        case method
        case headers
        case params
        case body
        case responseMapping = "response_mapping"
        case usePresets = "use_presets"
        case taskType = "task_type"
        case encoding
        case processors
    }
}

extension APIConfig {
    public func validate() throws {
        for (name, op) in operations {
            try op.validate(name: name, presets: paramPresets)
        }
    }
}

extension OperationConfig {
    public func validate(name: String, presets: [String: [String: String]]?) throws {
        if let encoding = encoding {
            let validEncodings = ["json", "url", "form", "query"]
            if !validEncodings.contains(encoding) {
                throw DynamicAPIError.configurationError(reason: "Operation '\(name)' has invalid encoding: \(encoding)")
            }
            
            if method.uppercased() == "GET" && (encoding == "json" || encoding == "form") {
                throw DynamicAPIError.configurationError(reason: "Operation '\(name)' is GET but has encoding '\(encoding)' which implies a body")
            }
        }
        
        if let usedPresets = usePresets {
            for presetName in usedPresets {
                if presets?[presetName] == nil {
                    throw DynamicAPIError.configurationError(reason: "Operation '\(name)' references missing preset: \(presetName)")
                }
            }
        }
        
        if method.uppercased() == "GET" && body != nil {
            throw DynamicAPIError.configurationError(reason: "Operation '\(name)' is GET but has a body defined")
        }
    }
}
