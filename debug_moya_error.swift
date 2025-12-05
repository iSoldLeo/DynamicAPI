import Foundation
import Moya

let error = MoyaError.requestMapping("bad url")
print("Error description: \(error.localizedDescription)")
