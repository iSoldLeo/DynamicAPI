import Foundation
import Combine
import Moya
import CombineMoya
import DynamicAPI
import os.log

public extension DynamicAPIClient {
    
    func callPublisher<T: Decodable>(_ operationName: String, params: [String: Any] = [:]) -> AnyPublisher<T, Error> {
        do {
            let operation = try configLoader.resolve(operation: operationName)
            
            // Pre-resolve params
            var resolvedParams = try ParamResolver.resolve(templates: operation.params, runtimeValues: params)
            var resolvedHeaders = operation.headers
            
            // Apply Processors
            if let processorNames = operation.processors {
                for name in processorNames {
                    if let processor = getProcessor(for: name) {
                        // Note: process() can throw
                        try processor.process(params: &resolvedParams, headers: &resolvedHeaders, operation: operation, runtimeValues: params)
                    }
                }
            }
            
            let resolvedPath = try ParamResolver.resolvePath(operation.path, runtimeValues: params)
            
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
            
            return provider.requestPublisher(target)
                .handleEvents(receiveSubscription: { _ in
                    os_log("📡 [Combine] Subscription Started: %{public}@", log: DynamicAPILogger.client, type: .info, operationName)
                }, receiveOutput: { response in
                    os_log("✅ [Combine] Response Received: Status %d", log: DynamicAPILogger.client, type: .info, response.statusCode)
                }, receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        os_log("❌ [Combine] Error: %{public}@", log: DynamicAPILogger.client, type: .error, error.localizedDescription)
                    } else {
                        os_log("🏁 [Combine] Completed", log: DynamicAPILogger.client, type: .info)
                    }
                })
                .tryMap { response -> T in
                    if let mappingKey = operation.responseMapping, let mapper = self.getMapper(for: mappingKey) {
                        return try mapper.map(response, to: T.self)
                    } else {
                        return try response.map(T.self)
                    }
                }
                .mapError { error -> Error in
                    if let dynamicError = error as? DynamicAPIError {
                        return dynamicError
                    }
                    // MoyaError is the Failure type of the upstream publisher, so this cast is technically redundant but safe.
                    // However, the compiler warns about it.
                    // Since we are in mapError, 'error' is the Failure type of the upstream.
                    // provider.requestPublisher returns AnyPublisher<Response, MoyaError>.
                    // So 'error' IS MoyaError.
                    if let moyaError = error as? MoyaError {
                        switch moyaError {
                        case .objectMapping, .jsonMapping, .stringMapping:
                            return DynamicAPIError.mappingError(reason: "Moya mapping failed", originalError: moyaError)
                        default:
                            return DynamicAPIError.networkError(originalError: moyaError)
                        }
                    }
                    return DynamicAPIError.unknownError(originalError: error)
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func callPublisher(_ operationName: String, params: [String: Any] = [:]) -> AnyPublisher<Response, Error> {
        do {
            let operation = try configLoader.resolve(operation: operationName)
            let target = try DynamicTarget(operation: operation, runtimeValues: params)
            
            return provider.requestPublisher(target)
                .handleEvents(receiveSubscription: { _ in
                    print("[DynamicAPI] 📡 [Combine] Subscription Started (Void): \(operationName)")
                }, receiveOutput: { response in
                    print("[DynamicAPI] ✅ [Combine] Response Received (Ignored Body)")
                }, receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("[DynamicAPI] ❌ [Combine] Error: \(error)")
                    } else {
                        print("[DynamicAPI] 🏁 [Combine] Completed")
                    }
                })
                .mapError { error -> Error in
                    // error is MoyaError here
                    return DynamicAPIError.networkError(originalError: error)
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}

