import Foundation
import Moya
import os.log

public class DynamicAPIClient: @unchecked Sendable {
    public let configLoader: ConfigLoader
    public let provider: MoyaProvider<DynamicTarget>
    
    private var mappers: [String: ResponseMapper] = [:]
    private var processors: [String: RequestProcessor] = [:]
    private let queue = DispatchQueue(label: "com.dynamicapi.client.mappers", attributes: .concurrent)
    
    public init(configLoader: ConfigLoader, provider: MoyaProvider<DynamicTarget> = MoyaProvider<DynamicTarget>()) {
        self.configLoader = configLoader
        self.provider = provider
    }
    
    public func register(mapper: ResponseMapper, for key: String) {
        queue.async(flags: .barrier) {
            self.mappers[key] = mapper
        }
    }
    
    public func getMapper(for key: String) -> ResponseMapper? {
        queue.sync {
            return mappers[key]
        }
    }
    
    public func register(processor: RequestProcessor, for key: String) {
        queue.async(flags: .barrier) {
            self.processors[key] = processor
        }
    }
    
    public func getProcessor(for key: String) -> RequestProcessor? {
        queue.sync {
            return processors[key]
        }
    }
    
    public func call<T: Decodable>(_ operationName: String, params: [String: Any] = [:]) async throws -> T {
        os_log("🚀 Request Start: %{public}@", log: DynamicAPILogger.client, type: .info, operationName)
        do {
            let operation = try configLoader.resolve(operation: operationName)
            
            // 预解析参数，以便处理器（Processors）可以对其进行处理
            var resolvedParams = try ParamResolver.resolve(templates: operation.params, runtimeValues: params)
            var resolvedHeaders = operation.headers
            
            // 应用处理器 (Processors)
            if let processorNames = operation.processors {
                for name in processorNames {
                    if let processor = getProcessor(for: name) {
                        os_log("⚙️ Applying Processor: %{public}@", log: DynamicAPILogger.client, type: .debug, name)
                        try processor.process(params: &resolvedParams, headers: &resolvedHeaders, operation: operation, runtimeValues: params)
                    } else {
                        os_log("⚠️ Processor not found: %{public}@", log: DynamicAPILogger.client, type: .error, name)
                        // 是否应该抛出异常？目前先仅记录警告。
                    }
                }
            }
            
            // 使用处理后的参数/Headers 重构 Target
            // 注意：DynamicTarget 构造函数目前在内部解析参数。
            // 我们需要一种方法来传递已经解析过的参数。
            // 让我们修改 DynamicTarget 以可选地接受已解析的参数，或者创建一个新的 init。
            // 或者更好的是，由于 DynamicTarget 逻辑很复杂（路径解析等），
            // 我们应该让 DynamicTarget 进行初始解析，然后应用处理器？
            // 但是 DynamicTarget 是不可变结构体。
            
            // 替代方案：将处理器传递给 DynamicTarget？不，DynamicTarget 不应该知道处理器的逻辑（关注点分离）。
            // 最佳方法：
            // 1. 解析路径（使用 runtimeValues）
            // 2. 解析参数（使用 runtimeValues）
            // 3. 解析 Body（使用 runtimeValues）
            // 4. 将处理器应用于参数/Body/Headers
            // 5. 使用最终值创建 DynamicTarget。
            
            // 为此，我们需要公开解析逻辑或使 DynamicTarget init 接受最终值。
            // 让我们向 DynamicTarget 添加一个新的 init，该 init 接受预解析的值。
            
            let resolvedPath = try ParamResolver.resolvePath(operation.path, runtimeValues: params)
            
            // Body 解析
            var resolvedBody: JSONValue? = nil
            if let bodyTemplate = operation.body {
                let jsonTemplate = JSONValue(bodyTemplate)
                resolvedBody = try ParamResolver.resolveJSON(template: jsonTemplate, runtimeValues: params)
            }
            
            // 应用处理器（现在我们有了 resolvedParams, resolvedHeaders, resolvedBody）
            // 等等，RequestProcessor 协议目前只接受 params 和 headers。
            // 如果我们需要对 Body 进行签名，我们需要更新协议。
            // 对于 Bilibili，签名通常涉及查询参数 + App Secret。
            // 但是有时 Body 参数也需要签名？
            // 按照协议，目前让我们坚持使用 params（Query/Form）。
            
            if let processorNames = operation.processors {
                for name in processorNames {
                    if let processor = getProcessor(for: name) {
                        try processor.process(params: &resolvedParams, headers: &resolvedHeaders, operation: operation, runtimeValues: params)
                    }
                }
            }
            
            let target = DynamicTarget(
                operation: operation,
                resolvedPath: resolvedPath,
                resolvedParams: resolvedParams,
                resolvedBody: resolvedBody,
                resolvedHeaders: resolvedHeaders
            )
            
            os_log("🎯 Target Resolved: %{public}@ %{public}@", log: DynamicAPILogger.client, type: .debug, "\(target.method)", target.path)
            
            let response = try await provider.request(target)
            os_log("✅ Response Received: Status %d", log: DynamicAPILogger.client, type: .info, response.statusCode)
            
            // Validate status code (200-299)
            let validatedResponse = try response.filterSuccessfulStatusCodes()
            
            var mapper: ResponseMapper?
            if let mappingKey = operation.responseMapping {
                if let foundMapper = getMapper(for: mappingKey) {
                    mapper = foundMapper
                    os_log("🗺️ Using Mapper: %{public}@", log: DynamicAPILogger.client, type: .debug, mappingKey)
                } else {
                    throw DynamicAPIError.configurationError(reason: "Mapper not found: \(mappingKey)")
                }
            }
            
            if let mapper = mapper {
                let result = try mapper.map(validatedResponse, to: T.self)
                os_log("📦 Mapping Success", log: DynamicAPILogger.client, type: .debug)
                return result
            } else {
                let result = try validatedResponse.map(T.self)
                os_log("📦 Default Mapping Success", log: DynamicAPILogger.client, type: .debug)
                return result
            }
        } catch {
            let mappedError = mapError(error)
            os_log("❌ Error: %{public}@", log: DynamicAPILogger.client, type: .error, mappedError.localizedDescription)
            throw mappedError
        }
    }
    
    /// 无返回值的调用（忽略响应体）
    public func call(_ operationName: String, params: [String: Any] = [:]) async throws {
        os_log("🚀 Request Start (Void): %{public}@", log: DynamicAPILogger.client, type: .info, operationName)
        do {
            let operation = try configLoader.resolve(operation: operationName)
            
            // 预解析参数
            var resolvedParams = try ParamResolver.resolve(templates: operation.params, runtimeValues: params)
            var resolvedHeaders = operation.headers
            
            // 应用处理器
            if let processorNames = operation.processors {
                for name in processorNames {
                    if let processor = getProcessor(for: name) {
                        try processor.process(params: &resolvedParams, headers: &resolvedHeaders, operation: operation, runtimeValues: params)
                    }
                }
            }
            
            let resolvedPath = try ParamResolver.resolvePath(operation.path, runtimeValues: params)
            // Body 解析
            var resolvedBody: JSONValue? = nil
            if let bodyTemplate = operation.body {
                let jsonTemplate = JSONValue(bodyTemplate)
                resolvedBody = try ParamResolver.resolveJSON(template: jsonTemplate, runtimeValues: params)
            }
            
            let target = DynamicTarget(
                operation: operation,
                resolvedPath: resolvedPath,
                resolvedParams: resolvedParams,
                resolvedBody: resolvedBody,
                resolvedHeaders: resolvedHeaders
            )
            
            os_log("🎯 Target Resolved: %{public}@ %{public}@", log: DynamicAPILogger.client, type: .debug, "\(target.method)", target.path)
            
            let response = try await provider.request(target)
            _ = try response.filterSuccessfulStatusCodes()
            os_log("✅ Response Received (Ignored Body)", log: DynamicAPILogger.client, type: .info)
        } catch {
            let mappedError = mapError(error)
            os_log("❌ Error: %{public}@", log: DynamicAPILogger.client, type: .error, mappedError.localizedDescription)
            throw mappedError
        }
    }
    
    /// 下载文件
    /// - Parameters:
    ///   - operationName: 配置中的操作名称
    ///   - params: 运行时参数
    ///   - destination: 文件保存的本地 URL
    /// - Returns: 下载文件的 URL（与 destination 相同）
    public func download(_ operationName: String, params: [String: Any] = [:], destination: URL) async throws -> URL {
        os_log("🚀 Download Start: %{public}@", log: DynamicAPILogger.client, type: .info, operationName)
        do {
            let operation = try configLoader.resolve(operation: operationName)
            
            // 确保任务类型是下载
            guard operation.taskType == "download" else {
                throw DynamicAPIError.configurationError(reason: "Operation '\(operationName)' is not configured as a download task")
            }
            
            // 预解析参数
            var resolvedParams = try ParamResolver.resolve(templates: operation.params, runtimeValues: params)
            var resolvedHeaders = operation.headers
            
            // 应用处理器
            if let processorNames = operation.processors {
                for name in processorNames {
                    if let processor = getProcessor(for: name) {
                        try processor.process(params: &resolvedParams, headers: &resolvedHeaders, operation: operation, runtimeValues: params)
                    }
                }
            }
            
            let resolvedPath = try ParamResolver.resolvePath(operation.path, runtimeValues: params)
            
            let target = DynamicTarget(
                operation: operation,
                resolvedPath: resolvedPath,
                resolvedParams: resolvedParams,
                resolvedBody: nil,
                resolvedHeaders: resolvedHeaders,
                downloadDestination: destination
            )
            
            os_log("🎯 Target Resolved (Download): %{public}@ %{public}@", log: DynamicAPILogger.client, type: .debug, "\(target.method)", target.path)
            
            let response = try await provider.request(target)
            
            // Validate status code
            _ = try response.filterSuccessfulStatusCodes()
            
            os_log("✅ Download Success: %{public}@", log: DynamicAPILogger.client, type: .info, destination.path)
            return destination
        } catch {
            let mappedError = mapError(error)
            os_log("❌ Error: %{public}@", log: DynamicAPILogger.client, type: .error, mappedError.localizedDescription)
            throw mappedError
        }
    }
    
    private func mapError(_ error: Error) -> DynamicAPIError {
        if let dynamicError = error as? DynamicAPIError {
            return dynamicError
        } else if let moyaError = error as? MoyaError {
            switch moyaError {
            case .objectMapping, .jsonMapping, .stringMapping:
                return .mappingError(reason: "Moya mapping failed", originalError: moyaError)
            default:
                return .networkError(originalError: moyaError)
            }
        } else if let decodingError = error as? DecodingError {
            return .mappingError(reason: "Decoding failed", originalError: decodingError)
        } else {
            return .unknownError(originalError: error)
        }
    }
}
