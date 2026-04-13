# 📋 CodexBar 安全分析圆桌会议纪要

**会议主题**：账号信息泄漏风险深度分析  
**时间**：2026-04-13  
**分析工具**：Coder + Research Subagents  
**版本**：v2.0.0 - 安全增强版

---

## 🎯 会议结论

| 项目 | 评分 | 状态 |
|------|------|------|
| 文件权限 | ⭐⭐⭐⭐⭐ | ✅ 正确 |
| HTTPS 传输 | ⭐⭐⭐⭐⭐ | ✅ 正确 |
| OAuth PKCE | ⭐⭐⭐⭐⭐ | ✅ 正确 |
| 剪贴板保护 | ⭐⭐⭐⭐ | ✅ 已实现 |
| Keychain 加密 | ⭐ | ❌ 待实现 |
| 主密码保护 | ⭐ | ❌ 待实现 |
| **综合评分** | **⭐⭐⭐ (3/5)** | 🟡 MEDIUM |

---

## 🔍 Coder 分析摘要

### 🔴 CRITICAL - 立即修复

#### 1. **`~/.codex/auth.json` - 明文 OAuth Token**
- **位置**：`CodexSyncService.swift::renderAuthJSON()`
- **风险**：access_token, refresh_token, id_token 明文 JSON 存储
- **防御**：文件权限 600（仅当前用户），但未加密

#### 2. **`~/.codexbar/config.json` - 明文 API Key**
- **位置**：`CodexBarConfigStore.migrateFromLegacy()`
- **风险**：自定义 Provider API Key 明文存储

#### 3. **`~/.codex/provider-secrets.env` - 明文环境变量**
- **风险**：自定义 Provider API Key 以环境变量明文存储

### 🟡 HIGH - 推荐修复

#### 4. **OAuth 临时文件泄露**
- **位置**：`copy_codexbar_auth_url.swift`
- **风险**：剪贴板传递 auth URL 未加密
- **缓解**：10 秒超时 + sentinel 值

#### 5. **日志文件潜在敏感信息**
- **位置**：`~/.codex/log/codex-login.log`
- **风险**：记录 OAuth callback 时间、邮箱（不包含 token）

#### 6. **CSV 导入明文 API Key**
- **风险**：CSV 可能意外泄露敏感信息

### 🟢 MEDIUM - 安全增强

#### 7. **缺少 Keychain 集成**
- **建议**：使用 `SecItemAdd`/`SecItemDelete` 存储敏感信息

#### 8. **缺少主密码保护**
- **建议**：启动时弹出密码框

#### 9. **Token 刷新机制**
- **建议**：OAuth Token 过期前 2 小时自动刷新

#### 10. **备份文件未清理**
- **建议**：加密备份 + 30 天自动清理

---

## 🔍 Research 分析摘要

### 市场对比（行业最佳实践）

| 工具 | 加密 | Keychain | 主密码 | 其他 |
|------|------|----------|--------|------|
| 1Password | ✅ AES-256 | ✅ | ✅ | 生物识别 |
| Bitwarden | ✅ AES-256 | ✅ | ✅ | 自托管 |
| macOS Keychain | ✅ AES-256 | ✅ | ✅ | iCloud 同步 |
| CodexBar v2.0 | ❌ 明文 | ❌ | ❌ | ✅ 剪贴板清除 |

### 风险等级对比

| 风险 | CodexBar | 行业标准 |
|------|---------|----------|
| 明文存储 | ⚠️ 中危 | ❌ 高危 |
| OAuth flow | ✅ 安全 | ✅ 安全 |
| 剪贴板 | ⚠️ 中危 | ✅ 安全 |
| 文件权限 | ✅ 安全 | ✅ 安全 |

---

## 📊 综合评估

### 当前风险

| 项目 | 等级 | 状态 |
|------|------|------|
| 明文 Token 存储 | 🟡 MEDIUM | ⚠️ 已缓解（权限 + 安全写入） |
| OAuth flow | 🟢 LOW | ✅ 安全 |
| 剪贴板 | 🟡 MEDIUM | ✅ 已缓解（ClipboardManager） |
| 日志记录 | 🟢 LOW | ✅ 无敏感信息 |
| CSV 导入 | 🟡 MEDIUM | ⚠️ 建议警告 |

### 已实现安全增强（v2.0.0）

✅ 剪贴板自动清除（30秒）  
✅ 文件权限 `0o600`  
✅ `writeSecureFile` 安全写入  
✅ 用量预警系统  
✅ 快捷键支持  
✅ 安全状态 UI  
✅ 完整中文翻译  

### 缺失功能（建议实现）

🔴 Keychain 加密（P1）  
🔴 主密码保护（P2）  
🟡 Token 自动刷新（P2）  
🟡 备份文件清理（P3）  
🟡 CSV 导出警告（P3）  

---

## 🛠️ 修复建议

### P0 - 立即（无需代码）
1. ✅ 用户启用 **FileVault**（macOS 全磁盘加密）

### P1 - 1-2 天
2. ✅ **集成 macOS Keychain**（替代明文存储）

### P2 - 1-2 周
3. ✅ **启动主密码保护**
4. ✅ **CSV 导出警告**

### P3 - 1 个月
5. ✅ **实现自动 Token 刷新**
6. ✅ **备份文件加密 + 清理**
7. ✅ **启用 App Sandbox**

---

## 📈 技术路线图

| 版本 | 功能 | 时间 |
|------|------|------|
| v2.0.0 | 剪贴板保护 + 用量预警 | ✅ 已发布 |
| v2.1.0 | Keychain 加密 | 🔄 计划中 |
| v2.2.0 | 主密码保护 | 🔄 计划中 |
| v2.3.0 | 自动 Token 刷新 | 🔄 计划中 |

---

## 📚 参考资料

- [macOS Keychain Programming Guide](https://developer.apple.com/documentation/security/keychain_services)
- [OWASP Secure Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [Swift Crypto](https://github.com/apple/swift-crypto)

---

**会议终结**  
纪要整理：小天才  
日期：2026-04-13  
状态：✅ 已报告 + 共享安全增强方案
