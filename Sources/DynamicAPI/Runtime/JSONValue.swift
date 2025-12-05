import Foundation

public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
    
    public init(_ value: Any?) {
        guard let value = value else {
            self = .null
            return
        }
        
        if let boolVal = value as? Bool {
            self = .bool(boolVal)
        } else if let intVal = value as? Int {
            self = .number(Double(intVal))
        } else if let doubleVal = value as? Double {
            self = .number(doubleVal)
        } else if let stringVal = value as? String {
            self = .string(stringVal)
        } else if let arrayVal = value as? [Any] {
            self = .array(arrayVal.map { JSONValue($0) })
        } else if let dictVal = value as? [String: Any] {
            self = .object(dictVal.mapValues { JSONValue($0) })
        } else if let jsonVal = value as? JSONValue {
            self = jsonVal
        } else if let anyCodable = value as? AnyCodable {
            self = JSONValue(anyCodable.value)
        } else {
            // Fallback for unknown types, treat as string description or null?
            // For now, let's try to cast to String if possible, otherwise null
            self = .string(String(describing: value))
        }
    }
    
    public var value: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let v): return v
        case .number(let v): return v
        case .string(let v): return v
        case .array(let v): return v.map { $0.value }
        case .object(let v): return v.mapValues { $0.value }
        }
    }
    
    // Codable implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .number(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else if let arrayVal = try? container.decode([JSONValue].self) {
            self = .array(arrayVal)
        } else if let dictVal = try? container.decode([String: JSONValue].self) {
            self = .object(dictVal)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "JSONValue cannot be decoded")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}
