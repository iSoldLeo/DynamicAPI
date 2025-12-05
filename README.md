![DynamicAPI Logo](5007118adc2ef5f41ae56b5297f2bd0a11cbc6081eae854c624ba7fbe16d7cf5.png)

# DynamicAPI

基于 Moya 构建的配置驱动型动态 API 客户端。通过 JSON 配置文件定义 API 接口，极大简化网络层代码。

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)]()

## 🌟 核心特性

*   📄 **配置驱动**: 使用 JSON 文件集中管理 API 端点，无需为每个接口编写 Request 结构体。
*   🔄 **动态参数**: 支持 URL 路径 (`/users/$id`)、查询参数和 Body 中的动态变量替换。
*   🌍 **多环境管理**: 通过 Profile 机制（如 `dev`, `prod`）一键切换 Base URL 和全局 Header。
*   🛡️ **安全优先**: 内置路径遍历攻击拦截和敏感 Header（如 `Host`, `Content-Length`）过滤机制。
*   ⚡ **现代并发**: 原生支持 Swift Concurrency (`async/await`)。
*   🔗 **响应式编程**: 提供 `DynamicAPICombine` 模块，完整支持 Combine 框架。

## ✨ 核心价值：零编译热更新

传统的 Swift 开发中，API 变更通常意味着修改代码、重新编译、提交审核、等待用户更新。DynamicAPI 通过将 API 定义与 Swift 代码解耦，彻底改变了这一流程。

只要 Swift 代码中调用的 **操作名称 (Operation Name)**（如 `"login"`）保持不变，你可以在 **App 编译打包甚至发布后**，通过下发新的 JSON 配置文件实时改变网络行为：

1.  **🚑 线上紧急修复 (Hot Fix)**
    *   后端接口突然变更（如 `/v1/login` -> `/v2/new_login`）或参数结构调整。
    *   **无需发版**，只需更新服务器上的 JSON 配置，App 启动拉取后即可立即修复。

2.  **🔀 A/B 测试**
    *   给不同用户群下发不同的配置文件。
    *   同一套 App 代码，用户 A 请求 `/v1/home`，用户 B 请求 `/v2/home_new`，轻松验证新接口效果。

3.  **🌍 动态环境切换**
    *   内置 Profile 机制，支持在运行时（Runtime）无缝切换开发、测试、生产环境，无需重启 App。

## 📦 安装

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/DynamicAPI.git", from: "1.0.0")
]
```

## 🚀 快速开始

### 1. 定义配置文件

创建一个 JSON 文件（例如 `Endpoints.json`）来描述你的 API。

> 💡 **提示**: 项目根目录下提供了一个全功能的配置模版 `full_feature_template.json`，涵盖了 GET/POST/PUT/DELETE、文件下载、复杂 Body 等所有支持的场景。

**基础配置示例:**

```json
{
    "version": "1.0.0",
    "globals": {
        "base_url": "https://api.example.com/v1",
        "headers": {
            "Content-Type": "application/json",
            "User-Agent": "DynamicAPI/1.0"
        }
    },
    "profiles": {
        "dev": { "base_url": "https://dev-api.example.com/v1" },
        "prod": { "base_url": "https://api.example.com/v1" }
    },
    "operations": {
        "get_user": {
            "path": "/users/$user_id",
            "method": "GET",
            "description": "获取用户信息"
        },
        "create_post": {
            "path": "/posts",
            "method": "POST",
            "body": {
                "title": "$title",
                "content": "$content",
                "author_id": "$user_id"
            }
        }
    }
}
```

### 2. 初始化客户端

```swift
import DynamicAPI
import Moya

// 1. 加载配置
let configURL = Bundle.main.url(forResource: "Endpoints", withExtension: "json")!
let loader = try ConfigLoader.load(from: configURL)

// 2. (可选) 切换环境
loader.currentProfile = "dev"

// 3. 创建客户端
let client = DynamicAPIClient(configLoader: loader)
```

### 3. 发起请求

#### 使用 Async/Await

```swift
struct User: Decodable {
    let id: String
    let name: String
}

// 简单的 GET 请求，自动替换路径参数 $user_id
let user: User = try await client.call("get_user", params: ["user_id": "123"])

// POST 请求，自动替换 Body 中的参数
let postResponse: Post = try await client.call("create_post", params: [
    "title": "Hello World",
    "content": "这是使用 DynamicAPI 发送的内容",
    "user_id": "123"
])
```

#### 使用 Combine

```swift
import DynamicAPICombine

var cancellables = Set<AnyCancellable>()

client.callPublisher("get_user", params: ["user_id": "123"])
    .sink(receiveCompletion: { completion in
        if case .failure(let error) = completion {
            print("Error: \(error)")
        }
    }, receiveValue: { (user: User) in
        print("User: \(user.name)")
    })
    .store(in: &cancellables)
```

## 📚 配置详解 (Configuration Reference)

配置文件必须符合以下 JSON Schema。

### 顶层结构

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `version` | String | 否 | 配置文件的版本号。 |
| `globals` | Object | **是** | 全局配置，包含 `base_url` 和公共 `headers`。 |
| `profiles` | Object | 否 | 环境配置集。Key 为环境名（如 `dev`），Value 为覆盖配置。 |
| `operations` | Object | **是** | API 操作定义集。Key 为操作名（如 `get_user`）。 |
| `param_presets` | Object | 否 | 参数预设集，用于定义通用的参数组合（如分页）。 |

### Operation 对象

每个操作定义支持以下字段：

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `path` | String | **是** | API 路径。支持 `$param` 占位符（如 `/users/$id`）。 |
| `method` | String | **是** | HTTP 方法 (`GET`, `POST`, `PUT`, `DELETE` 等)。 |
| `params` | Object | 否 | URL 查询参数。Value 若以 `$` 开头则为动态参数。 |
| `body` | Object | 否 | HTTP Body 参数（仅限 POST/PUT）。支持动态参数和嵌套结构。 |
| `headers` | Object | 否 | 该操作特有的 Header，会覆盖全局 Header。 |
| `encoding` | String | 否 | 编码方式：`json` (默认), `url`, `form`, `query`。 |
| `task_type` | String | 否 | 任务类型：`request` (默认), `download`, `upload`。 |
| `use_presets` | Array | 否 | 引用 `param_presets` 中的预设名称列表。 |
| `processors` | Array | 否 | 请求处理器名称列表（需在代码中注册）。 |
| `response_mapping` | String | 否 | 响应映射器名称（需在代码中注册）。 |
| `description` | String | 否 | 操作说明文档。 |

## 💡 高级功能

### 1. 复杂请求类型

DynamicAPI 支持多种复杂的请求场景，包括：

*   **表单提交**: 设置 `encoding: "form"`。
*   **Query Only POST**: 设置 `encoding: "query"`，即使是 POST 请求参数也会放在 URL 中。
*   **混合请求**: 同时包含 `params` (URL) 和 `body` (JSON)。
*   **文件下载**: 设置 `task_type: "download"`，使用 `client.download(...)` 方法调用。

### 2. 预设参数 (Presets)

对于分页、鉴权等通用参数，可以使用预设：

```json
"param_presets": {
    "pagination": { "page": "1", "limit": "20" }
},
"operations": {
    "get_feed": {
        "path": "/feed",
        "method": "GET",
        "use_presets": ["pagination"]
    }
}
```

### 3. 处理器与映射器 (Processors & Mappers)

通过代码注册自定义逻辑：

```swift
// 注册请求处理器（如签名）
client.register(processor: SignProcessor(), for: "SignProcessor")

// 注册响应映射器（如解包）
client.register(mapper: UserMapper(), for: "UserMapper")
```

在 JSON 中引用：

```json
"create_order": {
    "path": "/orders",
    "method": "POST",
    "processors": ["SignProcessor"],
    "response_mapping": "UserMapper"
}
```

## 🔒 安全说明

DynamicAPI 内置了多层安全防护：

1.  **路径遍历拦截**: 自动检测并阻止包含 `../` 或绝对路径（如 `https://evil.com`）的恶意配置。
2.  **Header 黑名单**: 自动过滤 `Host`, `Content-Length` 等敏感 Header。
3.  **Cookie 安全**: 正常支持 `Cookie` 和 `Authorization` 字段。

## 📄 许可证

本项目采用 GPLv3 许可证。
