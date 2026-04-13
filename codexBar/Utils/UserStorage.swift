import Foundation
import SwiftUI
import Combine

/// UserDefaults 属性包装器
@propertyWrapper
struct UserStorage<Value> {
    let key: String
    let defaultValue: Value

    var wrappedValue: Value {
        get {
            UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue
        }
        nonmutating set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }
}

extension UserStorage: DynamicProperty {}