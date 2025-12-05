import Foundation

/// 用于在发送请求前处理请求的协议。
/// 处理器可以修改参数和 Headers，从而实现签名、时间戳注入等逻辑。
public protocol RequestProcessor: Sendable {
    /// 处理请求参数和 Headers。
    /// - Parameters:
    ///   - params: 已解析的参数（取决于上下文，通常是 Query/Form）。
    ///   - headers: 已解析的 Headers。
    ///   - operation: 操作配置上下文。
    ///   - runtimeValues: 调用时传递的原始运行时值。
    func process(params: inout [String: Any], headers: inout [String: String], operation: ResolvedOperation, runtimeValues: [String: Any]) throws
}
