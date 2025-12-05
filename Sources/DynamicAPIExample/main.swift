import Foundation
import DynamicAPI
import DynamicAPICombine
import Combine

// 1. Define a sample configuration (using httpbin.org for real testing)
let jsonConfig = """
{
    "version": "1.0",
    "globals": {
        "base_url": "https://httpbin.org",
        "timeout": 30
    },
    "profiles": {
        "dev": {
            "base_url": "https://httpbin.org"
        }
    },
    "operations": {
        "get_example": {
            "path": "/get",
            "method": "GET",
            "params": {
                "foo": "bar",
                "user_id": "$user_id"
            }
        },
        "post_example": {
            "path": "/post",
            "method": "POST",
            "body": {
                "message": "$msg"
            }
        }
    }
}
"""

struct HttpBinResponse: Decodable {
    let url: String
    let args: [String: String]?
    let json: [String: String]?
}

func run() async {
    print("--- Starting DynamicAPI Real World Test ---")
    
    do {
        // 2. Load Config
        guard let data = jsonConfig.data(using: .utf8) else { return }
        let loader = try ConfigLoader.load(from: data)
        loader.currentProfile = "dev"
        
        // 3. Init Client
        let client = DynamicAPIClient(configLoader: loader)
        
        // 4. Test GET Request
        print("\n--- Testing GET Request ---")
        let getResult: HttpBinResponse = try await client.call("get_example", params: ["user_id": "12345"])
        print("GET Result URL: \(getResult.url)")
        print("GET Result Args: \(getResult.args ?? [:])")
        
        // 5. Test POST Request
        print("\n--- Testing POST Request ---")
        let postResult: HttpBinResponse = try await client.call("post_example", params: ["msg": "Hello DynamicAPI"])
        print("POST Result JSON: \(postResult.json ?? [:])")
        
        print("\n--- Test Finished Successfully ---")
        
    } catch {
        print("\n❌ Test Failed with error: \(error)")
    }
    
    exit(0)
}

// Run the async function
Task {
    await run()
}

// Keep runloop alive
RunLoop.main.run()
