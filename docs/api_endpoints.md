# DynamicAPI 对外公开端点（开发者 API）

本文件列出开发者可直接使用或实现的公开类型与方法，并给出用途、关键参数与注意事项。

## 核心加载与配置
- `ConfigLoader.load(from url: URL) throws -> ConfigLoader`
  - 从本地/远程已获取到的 JSON 配置初始化加载器，并做配置校验。
- `ConfigLoader.load(from data: Data) throws -> ConfigLoader`
  - 适用于内存中的配置数据（例如远程拉取后）。
- `ConfigLoader.currentProfile: String?`
  - 运行时选择 profile（如 dev/prod），影响 base_url 与全局 headers 的覆盖。
- `ConfigLoader.securityPolicy: SecurityPolicy`
  - 全局安全策略（默认强制 HTTPS，可选 base_url 域名白名单）。
  - 配置解析时若不符合策略会抛 `configurationError`。
  - 可选硬编码白名单：修改 `ConfigLoader.compiledAllowedBaseHosts`（源代码内），用于强制仅信任固定域名；若 runtime 未设置 allowedBaseHosts，则使用硬编码列表。

## 客户端调用
- `DynamicAPIClient.init(configLoader: ConfigLoader, provider: MoyaProvider<DynamicTarget> = MoyaProvider())`
  - 创建客户端，可注入自定义 `MoyaProvider` 以支持 stub/日志等。
- `register(mapper: ResponseMapper, for key: String)` / `getMapper(for:)`
  - 注册/获取自定义响应映射器（如解包、KeyPath 取值）。
- `register(processor: RequestProcessor, for key: String)` / `getProcessor(for:)`
  - 注册/获取请求处理器（如签名、时间戳、Header 注入）。
- `call<T: Decodable>(_ operationName: String, params: [String: Any] = [:]) async throws -> T`
  - 依据配置名发起请求并解码为 `T`。自动：参数占位符替换、处理器执行、状态码过滤（2xx）、映射器处理。
- `call(_ operationName: String, params: [String: Any] = [:]) async throws`
  - 同上，但忽略响应体。
- `download(_ operationName: String, params: [String: Any] = [:], destination: URL) async throws -> URL`
  - 仅适用于配置中 `task_type: "download"` 的操作；下载到指定路径（默认覆盖）。

## Combine 支持（在 `DynamicAPICombine` 模块）
- `DynamicAPIClient.callPublisher<T: Decodable>(_ operationName: String, params: [String: Any] = [:]) -> AnyPublisher<T, Error>`
  - 与 async 版行为一致：处理器执行、路径/参数解析、2xx 过滤、映射器支持。
- `DynamicAPIClient.callPublisher(_ operationName: String, params: [String: Any] = [:]) -> AnyPublisher<Response, Error>`
  - 返回原始 `Moya.Response`，同样执行处理器与状态码过滤。

## 可扩展协议
- `RequestProcessor`
  - `process(params:inout [String: Any], headers: inout [String: String], operation: ResolvedOperation, runtimeValues: [String: Any]) throws`
  - 用于签名、鉴权、Header/参数注入；在 `call`/`callPublisher` 中、解析后构造 Target 前执行。
- `ResponseMapper`
  - `map<T: Decodable>(_ response: Response, to type: T.Type) throws -> T`
  - 自定义响应解包/转换；在配置指定 `response_mapping` 时触发。

## 运行时目标构建（高级用例）
- `DynamicTarget` 可直接用 `init(operation:resolvedPath:resolvedParams:resolvedBody:resolvedHeaders:downloadDestination:)` 构造，或 `init(operation:runtimeValues:)` 让其内部解析占位符。
  - 一般不需要直接使用，除非自定义 Moya Provider 行为或测试场景。

## 解析与通用类型（通常无需直接调用）
- `ParamResolver.resolve/resolvePath/resolveJSON`：占位符解析与路径编码，已由客户端调用链自动使用。
- `JSONValue` / `AnyCodable`：内部用于表达任意 JSON 结构；开发者偶尔在自定义处理器或测试中会用到。

## 常见注意事项
- 配置 `path` 禁止绝对 URL（含 `://` 或以 `//` 开头），以防域名劫持。
- Base URL 默认强制 HTTPS；如需允许特定域名，设置 `ConfigLoader.securityPolicy.allowedBaseHosts`。
- 缺失必填占位符会抛 `parameterError`；处理器未注册/缺失会记录或抛 `configurationError`（对于映射器）。
- Combine 与 async 行为保持一致：处理器执行、状态码过滤、错误映射均对齐。
- 下载任务需在配置中声明 `task_type: "download"`，否则 `download` 会抛配置错误。
