import Foundation
import Moya

public enum DynamicAPIError: Error, LocalizedError {
    /// 配置相关错误（例如：操作未找到，无效的 URL）
    case configurationError(reason: String)
    
    /// 参数解析错误（例如：缺少必填参数）
    case parameterError(reason: String, parameter: String?)
    
    /// 网络相关错误（封装 MoyaError）
    case networkError(originalError: MoyaError)
    
    /// 传输错误（例如：连接问题，状态码错误）
    case transportError(originalError: Error)
    
    /// 数据映射/解码错误
    case mappingError(reason: String, originalError: Error?)
    
    /// 未知或意外错误
    case unknownError(originalError: Error)
    
    public var errorDescription: String? {
        switch self {
        case .configurationError(let reason):
            return "Configuration Error: \(reason)"
        case .parameterError(let reason, let parameter):
            if let param = parameter {
                return "Parameter Error: \(reason) (Parameter: \(param))"
            } else {
                return "Parameter Error: \(reason)"
            }
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .transportError(let error):
            return "Transport Error: \(error.localizedDescription)"
        case .mappingError(let reason, let originalError):
            if let err = originalError {
                return "Mapping Error: \(reason) (Original: \(err.localizedDescription))"
            } else {
                return "Mapping Error: \(reason)"
            }
        case .unknownError(let error):
            return "Unknown Error: \(error.localizedDescription)"
        }
    }
}
