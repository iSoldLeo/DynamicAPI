import Foundation
import Moya

public struct ResolvedOperation {
    public let baseURL: URL
    public let path: String
    public let method: Moya.Method
    public let headers: [String: String]
    public let params: [String: Any]
    public let body: Any?
    public let responseMapping: String?
    public let taskType: String?
    public let encoding: String?
    public let processors: [String]?
    
    public init(
        baseURL: URL,
        path: String,
        method: Moya.Method,
        headers: [String: String],
        params: [String: Any],
        body: Any?,
        responseMapping: String?,
        taskType: String? = nil,
        encoding: String? = nil,
        processors: [String]? = nil
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.headers = headers
        self.params = params
        self.body = body
        self.responseMapping = responseMapping
        self.taskType = taskType
        self.encoding = encoding
        self.processors = processors
    }
}
