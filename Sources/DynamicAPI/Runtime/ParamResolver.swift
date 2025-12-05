import Foundation
import os.log

public struct ParamResolver {
    
    /// 通过将占位符替换为运行时值来解析参数。
    /// - Parameters:
    ///   - templates: 配置中的参数模板（例如：["userId": "$user_id", "type": "feed"]）。
    ///   - runtimeValues: 运行时提供的实际值（例如：["user_id": "123"]）。
    /// - Returns: 包含解析后值的字典。
    public static func resolve(templates: [String: Any], runtimeValues: [String: Any]) throws -> [String: Any] {
        var resolved = [String: Any]()
        
        for (key, valueTemplate) in templates {
            resolved[key] = try resolveValue(template: valueTemplate, runtimeValues: runtimeValues)
        }
        
        return resolved
    }
    
    /// 递归解析值模板。
    public static func resolveValue(template: Any, runtimeValues: [String: Any]) throws -> Any {
        if let stringTemplate = template as? String {
            if stringTemplate.hasPrefix("$$") {
                return String(stringTemplate.dropFirst())
            } else if stringTemplate.hasPrefix("$") {
                let placeholderKey = String(stringTemplate.dropFirst())
                if let runtimeValue = runtimeValues[placeholderKey] {
                    return runtimeValue
                } else {
                    throw DynamicAPIError.parameterError(reason: "Missing required parameter", parameter: placeholderKey)
                }
            } else {
                return stringTemplate
            }
        } else if let dictTemplate = template as? [String: Any] {
            var resolvedDict = [String: Any]()
            for (k, v) in dictTemplate {
                resolvedDict[k] = try resolveValue(template: v, runtimeValues: runtimeValues)
            }
            return resolvedDict
        } else if let arrayTemplate = template as? [Any] {
            return try arrayTemplate.map { try resolveValue(template: $0, runtimeValues: runtimeValues) }
        } else if let anyCodable = template as? AnyCodable {
            return try resolveValue(template: anyCodable.value, runtimeValues: runtimeValues)
        } else {
            // For other types (Int, Bool, etc.), return as is
            return template
        }
    }
    
    /// 解析 JSONValue 模板。
    public static func resolveJSON(template: JSONValue, runtimeValues: [String: Any]) throws -> JSONValue {
        switch template {
        case .string(let stringTemplate):
            let resolved = try resolveValue(template: stringTemplate, runtimeValues: runtimeValues)
            return JSONValue(resolved)
        case .array(let arrayTemplate):
            let resolvedArray = try arrayTemplate.map { try resolveJSON(template: $0, runtimeValues: runtimeValues) }
            return .array(resolvedArray)
        case .object(let dictTemplate):
            var resolvedDict = [String: JSONValue]()
            for (k, v) in dictTemplate {
                resolvedDict[k] = try resolveJSON(template: v, runtimeValues: runtimeValues)
            }
            return .object(resolvedDict)
        default:
            return template
        }
    }
    
    /// 解析路径参数。
    /// - Parameters:
    ///   - path: 路径模板（例如："/users/$user_id/feed"）。
    ///   - runtimeValues: 运行时提供的实际值。
    /// - Returns: 解析后的路径。
    public static func resolvePath(_ path: String, runtimeValues: [String: Any]) throws -> String {
        var resolvedPath = path
        
        // 正则表达式查找占位符：$variableName
        // 我们假设变量名由字母数字和下划线组成
        let regex = try NSRegularExpression(pattern: "\\$([a-zA-Z0-9_]+)", options: [])
        let nsString = resolvedPath as NSString
        let matches = regex.matches(in: resolvedPath, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // 反向迭代以避免范围失效
        for match in matches.reversed() {
            let placeholderRange = match.range(at: 0)
            let keyRange = match.range(at: 1)
            let key = nsString.substring(with: keyRange)
            
            if let value = runtimeValues[key] {
                let stringValue = "\(value)"
                // 使用排除 '/' 的字符集，以确保路径结构被保留
                var allowed = CharacterSet.urlPathAllowed
                allowed.remove("/")
                guard let encodedValue = stringValue.addingPercentEncoding(withAllowedCharacters: allowed) else {
                     os_log("❌ Failed to encode path parameter: %{public}@", log: DynamicAPILogger.runtime, type: .error, key)
                     throw DynamicAPIError.parameterError(reason: "Failed to encode path parameter", parameter: key)
                }
                resolvedPath = (resolvedPath as NSString).replacingCharacters(in: placeholderRange, with: encodedValue)
            } else {
                os_log("❌ Missing required path parameter: %{public}@", log: DynamicAPILogger.runtime, type: .error, key)
                throw DynamicAPIError.parameterError(reason: "Missing required path parameter", parameter: key)
            }
        }
        
        return resolvedPath
    }
}
