# DynamicAPI Copilot Instructions

This repository hosts **DynamicAPI**, a configuration-driven network client for Swift based on Moya. It allows defining API endpoints via JSON configuration rather than static Swift code.

## 🏗 Architecture Overview

- **Core Pattern**: The library parses a JSON configuration (`Endpoints.json`) to dynamically construct `Moya.TargetType` at runtime.
- **Key Components**:
  - `ConfigLoader`: Loads and validates the JSON configuration.
  - `DynamicAPIClient`: The primary entry point. It resolves operations and executes requests using `MoyaProvider`.
  - `DynamicTarget`: The dynamic implementation of `Moya.TargetType`. It holds the resolved path, method, headers, and body.
  - `ParamResolver`: Handles variable substitution (e.g., `$userId`) in paths, query parameters, and JSON bodies.
  - `RequestProcessor`: Protocol for middleware that modifies requests (e.g., for signing or auth) before transmission.
  - `ResponseMapper`: Protocol for middleware that transforms responses before decoding.

## 🧩 Configuration-Driven Development

When adding or modifying APIs, **always start with the JSON configuration**.

### 1. Defining Operations (`Endpoints.json`)
Define APIs in the `operations` section. Use `$` prefix for dynamic variables.

```json
"get_user": {
    "path": "/users/$user_id",
    "method": "GET",
    "description": "Fetch user details"
}
```

### 2. Calling APIs
Use `DynamicAPIClient.call` with the operation ID defined in the JSON.

```swift
// Usage
let user: User = try await client.call("get_user", params: ["user_id": "123"])
```

## 🛠 Key Patterns & Conventions

- **Parameter Resolution**:
  - `$var`: Replaced by `params["var"]`. Throws if missing.
  - `$$var`: Escaped to literal `$var`.
  - **Path Params**: Automatically URL-encoded (except `/`).
  - **Body**: Supports nested JSON templates.

- **Middleware**:
  - **RequestProcessor**: Use for request signing, timestamp injection, or complex header logic. Register via `client.register(processor:for:)`.
  - **ResponseMapper**: Use for standardizing response structures (e.g., unwrapping a `data` field). Register via `client.register(mapper:for:)`.

- **Concurrency**:
  - The project uses Swift Concurrency (`async/await`).
  - `DynamicAPIClient` and processors are `Sendable`.
  - Avoid completion handlers; prefer `async` functions.
  - **Thread Safety**: `ConfigLoader` profile switching must be handled carefully in concurrent contexts.

- **Security**:
  - **SSRF Protection**: The library validates URLs to prevent host redirection attacks.
  - **Header Injection**: Restricted headers (e.g., `Host`, `Content-Length`) are filtered.
  - **Reference**: See `SecurityTests.swift` for enforcement logic.

## 🧪 Testing Strategy

- **Philosophy**: Tests are "Specification-Driven". The test suite defines the library's contract.
- **Golden Config Pattern**: Use `full_config.json` as the source of truth for regression testing configuration parsing.
- **Black-Box Testing**: Treat `DynamicAPIClient` as a black box.
- **Mocking**: 
  - **Unit Tests**: MUST use `MoyaProvider` with `stubClosure` (e.g., `MoyaProvider.immediatelyStub`).
  - **Integration Tests**: Real network tests (e.g., `RealNetworkTests`, `BilibiliTests`) are separated from unit tests.
- **Fixtures**: Store test configurations in `Tests/DynamicAPITests/Resources`.
- **Key Test Files**:
  - `AdvancedEncodingTests.swift`: Defines strict encoding rules (JSON vs URL vs Query).
  - `SecurityTests.swift`: Enforces security boundaries.
  - `ComplexScenarioTests.swift`: End-to-end validation using complex configs.

## 📂 Important Files

- `Sources/DynamicAPI/DynamicAPIClient.swift`: Main client logic.
- `Sources/DynamicAPI/Runtime/DynamicTarget.swift`: How requests are constructed.
- `Sources/DynamicAPI/Runtime/ParamResolver.swift`: Logic for variable substitution.
- `Sources/DynamicAPI/Config/ConfigLoader.swift`: Configuration parsing logic.
- `TESTING_PLAN.md`: Comprehensive testing guide.
