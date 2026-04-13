# CodexBar 安全与转化分析报告

## 项目简介
CodexBar 是一个 macOS 菜单栏工具，用于在多个 OpenAI 账号/Provider 之间快速切换，同时保持同一个 `~/.codex` 会话池不被拆散。

---

## 🔐 安全分析

### 1. OAuth 流程（本地回调服务器）
**风险等级：中等**

**实现：**
- 本地运行 OAuth 回调服务器：`localhost:1455`
- 接收浏览器授权回调 `http://localhost:1455/auth/callback?code=...`
- 交换 token 后存储到本地配置

**风险：**
- ✅ 本地端口不会暴露到公网（仅 127.0.0.1）
- ⚠️ Token 以明文存储在 `~/.codexbar/config.json`
- ⚠️ `auth.json` 包含完整的 OAuth token（access_token, refresh_token, id_token）

** mitigations：**
- Token 存储在用户主目录（需要系统权限访问）
- macOS File System加密（FileVault）可 protection
- 建议启用 `writeSecureFile`（用 chmod 600）

### 2. API Key 存储（自定义 Provider）
**风险等级：高**

**实现：**
```swift
struct CodexBarProviderAccount {
    var apiKey: String?  // 明文存储
}
```

**风险：**
- ❌ API Key 明文存储在 config.json
- ❌ 无加密/数据库保护
- ❌ 可被任意读取 `~/.codexbar/config.json`

### 3. 同步到 `~/.codex`
**风险等级：中等**

**实现：**
- 将当前账号的 token/sync 到 `~/.codex/auth.json` 和 `~/.codex/config.toml`
- Codex Desktop 会读取这些文件

**风险：**
- ✅ 只在切换时写入（减少暴露窗口）
- ⚠️ 如果 Codex Desktop 被恶意软件控制，可能泄露
- ⚠️ 备份文件 `auth.json.backup` 可能残留敏感数据

### 4. 信息泄露场景

| 场景 | 风险 | 影响 |
|------|------|------|
| 分享 config.json | ❌ 高 | OAuth tokens + API keys 全泄露 |
| Terminal 命令历史 | ⚠️ 中 | If user types paths | 
| Time Machine 备份 | ⚠️ 中 | 恢复时保留敏感数据 |
| macOS 睡眠/休眠 | ⚠️ 低 | 内存中的 token 可能被提取 |
| 分享屏幕 | ⚠️ 低 | 界面显示 masked API key（6...4） |

### 5. 未实现的安全措施

❌ **Token 加密** - 应该用 macOS Keychain 存储敏感 token  
❌ **主密码保护** - 无解锁机制， anyone can access config  
❌ **自动清除令牌** - 无自动过期/刷新机制  
❌ **审计日志** - 无记录谁访问了哪个账号  
❌ **Process sandboxing** - 未启用 App Sandbox  

---

## 🔄 转化为个人项目的建议

### 方案A：安全性优先（推荐）

1. **用 Keychain 替换明文存储**
```swift
// 使用 macOS Keychain 存储 OAuth tokens
func saveTokenToKeychain(_ token: String, for account: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecValueData as String: token.data(using: .utf8)!,
    ]
    SecItemDelete(query as CFDictionary)  // remove existing
    SecItemAdd(query as CFDictionary, nil)
}
```

2. **启用主密码保护**
```swift
struct SecureLock {
    var isLocked: Bool = true
    
    func unlock(password: String) throws {
        // 验证密码，解密 config.json
    }
    
    func lock() {
        // 清除内存中的敏感数据
    }
}
```

3. **添加审计日志**
```swift
struct AuditEntry {
    let timestamp: Date
    let event: String  // "account_switch", "provider_added"
    let accountId: String?
}
```

### 方案B：简化版（快速上线）

1. **只存储 API Key，不存 OAuth token**
   - 用户每次手动登录
   - Token 只在内存中保留

2. **添加 config.json 加密**
```swift
// 用用户输入的 password 加密整个 config
func encryptConfig(_ config: CodexBarConfig, with password: String) throws -> Data {
    let data = try JSONEncoder().encode(config)
    return try AESGCM.encrypt(data, using: password)
}
```

3. **移除自定义 Provider 的 API Key 存储**
   - 改为每次使用时输入
   - 或使用系统 Keychain

---

## 📋 法律风险评估

### MIT License 兼容性
✅ CodexBar 使用 MIT License，可自由修改/商用/闭源  
✅ 上游项目 `xmasdong/codexbar` 和 `steipete/CodexBar` 都是 MIT  
✅ 需保留第三方 notices 文件

### 数据隐私
⚠️ 如果你的版本 收集 usage statistics → 需要 privacy policy  
⚠️ OAuth token 传输到 OpenAI → 受 GDPR/CCPA 约束  
⚠️ macOS Keychain 数据受 Apple Developer Program 要求约束

---

## ✅ 最低可交付版本（MVP）

| 功能 | 安全要求 | 实现难度 |
|------|----------|----------|
| 多账号管理 | ✅ 基本安全 | 低 |
| OAuth 切换 | ✅ 加密存储 | 中 |
| API Key 管理 | ⚠️ 至少 masking | 低 |
| 本地统计 | ✅ 无敏感数据 | 低 |
| 更新检查 | ✅ HTTPS | 低 |

---

## 🚀 个人项目改造路线图

### Phase 1：基础功能（4-7天）
- [ ] 保留账号管理 + 切换核心功能
- [ ] 添加 config.json 读写保护（chmod 600）
- [ ] 移除自定义 Provider 的 API Key 存储

### Phase 2：安全增强（7-14天）
- [ ] 集成 macOS Keychain 存储
- [ ] 添加主密码解锁
- [ ] 清除敏感数据（logout 时）

### Phase 3：生产就绪（14-21天）
- [ ] 启用 App Sandbox
- [ ] 审计日志 + 隐私政策
- [ ] 错误报告（匿名化）
- [ ] 单元测试 + 安全测试

---

## 📜 推荐的 License 变更

原项目 MIT → 你的项目建议：

```
Copyright (c) 2026 Your Name
All rights reserved.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

或选择更宽松的：**Apache 2.0**（需保留 NOTICE 文件）

---

## 📌 总结

| 维度 | 评分 | 说明 |
|------|------|------|
| 代码质量 | ⭐⭐⭐⭐ | 架构清晰，模块化好 |
| 安全性 | ⭐⭐ | 明文存储 OAuth token |
| 可转化性 | ⭐⭐⭐⭐ | MIT License + 功能明确 |
| 市场价值 | ⭐⭐⭐ | 多账号管理是痛点 |

**建议：** 先做 Phase 1-2（Keychain + 主密码），2周内可以上线 MVP，安全风险可控。
