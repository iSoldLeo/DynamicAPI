import Foundation
import Moya

public protocol ResponseMapper: Sendable {
    func map<T: Decodable>(_ response: Response, to type: T.Type) throws -> T
}

public struct DefaultJSONMapper: ResponseMapper {
    public init() {}
    public func map<T: Decodable>(_ response: Response, to type: T.Type) throws -> T {
        return try response.map(type)
    }
}

public struct KeyPathJSONMapper: ResponseMapper {
    public let keyPath: String
    public init(keyPath: String) {
        self.keyPath = keyPath
    }
    
    public func map<T: Decodable>(_ response: Response, to type: T.Type) throws -> T {
        return try response.map(type, atKeyPath: keyPath)
    }
}
