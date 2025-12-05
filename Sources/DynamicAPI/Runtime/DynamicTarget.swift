import Foundation
import Moya

public struct DynamicTarget: TargetType {
    
    public let operation: ResolvedOperation
    public let resolvedParams: [String: Any]
    public let resolvedBody: JSONValue?
    public let resolvedPath: String
    public let resolvedHeaders: [String: String]?
    public let downloadDestination: URL?
    
    /// 使用运行时值初始化（自动解析）
    public init(operation: ResolvedOperation, runtimeValues: [String: Any], downloadDestination: URL? = nil) throws {
        self.operation = operation
        self.downloadDestination = downloadDestination
        
        // 解析路径
        self.resolvedPath = try ParamResolver.resolvePath(operation.path, runtimeValues: runtimeValues)
        
        // 解析参数（Query）
        self.resolvedParams = try ParamResolver.resolve(templates: operation.params, runtimeValues: runtimeValues)
        
        // 解析 Body (JSON)
        if let bodyTemplate = operation.body {
            // 先将 AnyCodable 模板转换为 JSONValue 模板
            let jsonTemplate = JSONValue(bodyTemplate)
            self.resolvedBody = try ParamResolver.resolveJSON(template: jsonTemplate, runtimeValues: runtimeValues)
        } else {
            self.resolvedBody = nil
        }
        
        // 解析 Headers
        let headersAny = operation.headers.mapValues { $0 as Any }
        let resolvedAny = try ParamResolver.resolve(templates: headersAny, runtimeValues: runtimeValues)
        self.resolvedHeaders = resolvedAny.compactMapValues { "\($0)" }
    }
    
    /// 使用预解析值初始化（手动）
    public init(operation: ResolvedOperation, resolvedPath: String, resolvedParams: [String: Any], resolvedBody: JSONValue?, resolvedHeaders: [String: String]?, downloadDestination: URL? = nil) {
        self.operation = operation
        self.resolvedPath = resolvedPath
        self.resolvedParams = resolvedParams
        self.resolvedBody = resolvedBody
        self.resolvedHeaders = resolvedHeaders
        self.downloadDestination = downloadDestination
    }
    
    public init(config: APIConfig, endpointName: String, runtimeParams: [String: Any], downloadDestination: URL? = nil) throws {
        let loader = ConfigLoader(config: config)
        let operation = try loader.resolve(operation: endpointName)
        try self.init(operation: operation, runtimeValues: runtimeParams, downloadDestination: downloadDestination)
    }
    
    public var baseURL: URL {
        return operation.baseURL
    }
    
    public var path: String {
        return resolvedPath
    }
    
    public var method: Moya.Method {
        return operation.method
    }
    
    public var task: Task {
        // 处理下载任务
        if operation.taskType == "download" {
            let destURL = self.downloadDestination
            let path = self.resolvedPath
            
            let destination: DownloadDestination = { _, _ in
                if let dest = destURL {
                    return (dest, [.removePreviousFile, .createIntermediateDirectories])
                } else {
                    // 如果未提供目标路径，则回退到临时目录
                    let fileName = path.components(separatedBy: "/").last ?? "downloaded_file"
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    return (tempURL, [.removePreviousFile, .createIntermediateDirectories])
                }
            }
            
            if !resolvedParams.isEmpty {
                return .downloadParameters(parameters: resolvedParams, encoding: URLEncoding.default, destination: destination)
            } else {
                return .downloadDestination(destination)
            }
        }
        
        // 确定编码
        let encoding: ParameterEncoding
        if let encodingName = operation.encoding {
            switch encodingName.lowercased() {
            case "json":
                encoding = JSONEncoding.default
            case "url":
                encoding = URLEncoding.default
            case "form":
                encoding = URLEncoding.httpBody
            case "query":
                encoding = URLEncoding.queryString
            default:
                encoding = JSONEncoding.default
            }
        } else {
            // Default behavior
            if method == .get {
                encoding = URLEncoding.default
            } else {
                encoding = JSONEncoding.default
            }
        }
        
        if let body = resolvedBody {
            switch body {
            case .object(let dictBody):
                // Convert [String: JSONValue] to [String: Any] for Moya
                let rawDict = dictBody.mapValues { $0.value }
                
                if !resolvedParams.isEmpty {
                    // If we have both body and params
                    // If encoding is JSON, we use composite
                    if encoding is JSONEncoding {
                        return .requestCompositeParameters(
                            bodyParameters: rawDict,
                            bodyEncoding: JSONEncoding.default,
                            urlParameters: resolvedParams
                        )
                    } else {
                        // Fallback for other encodings
                        return .requestCompositeParameters(
                            bodyParameters: rawDict,
                            bodyEncoding: encoding,
                            urlParameters: resolvedParams
                        )
                    }
                } else {
                    return .requestParameters(parameters: rawDict, encoding: encoding)
                }
            default:
                // Body is not a dictionary (e.g. Array, Int, String)
                // We use requestJSONEncodable with JSONValue directly
                
                if !resolvedParams.isEmpty {
                    // We need to encode body to data manually to use requestCompositeData
                    do {
                        let data = try JSONEncoder().encode(body)
                        return .requestCompositeData(bodyData: data, urlParameters: resolvedParams)
                    } catch {
                        // Fallback to just body if encoding fails
                        return .requestJSONEncodable(body)
                    }
                } else {
                    return .requestJSONEncodable(body)
                }
            }
        } else {
            // No body
            if !resolvedParams.isEmpty {
                // If method is POST and we want Query params, we must use URLEncoding.queryString
                // If encoding was not specified, we default to JSONEncoding for POST in the logic above, 
                // BUT if there is NO body, we shouldn't use JSONEncoding for params unless we want params in JSON body.
                
                // If encoding is explicitly set, use it.
                // If not set:
                //   GET -> URLEncoding.default (Query)
                //   POST -> 
                //      If we want params in Body -> URLEncoding.default (Form) or JSONEncoding.default
                //      If we want params in Query -> URLEncoding.queryString
                
                // The previous implementation used URLEncoding.default for no-body case.
                // For POST, URLEncoding.default puts params in Body.
                // If user wants Query params on POST, they must set encoding="query" or we need smart default.
                
                // If encoding is set to "query", use queryString.
                return .requestParameters(parameters: resolvedParams, encoding: encoding)
            } else {
                return .requestPlain
            }
        }
    }
    
    public var headers: [String: String]? {
        return resolvedHeaders
    }
    
    public var sampleData: Data {
        return Data()
    }
}
