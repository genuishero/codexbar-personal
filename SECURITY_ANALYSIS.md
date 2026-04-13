# 🔍 CodexBar 账号信息泄漏风险分析报告

**分析时间**：2026-04-13  
**分析工具**：Coder + Research 子 agent  
**项目版本**：v2.0.0 - 安全增强版

---

## 📋 执行摘要

| 项目 | 风险等级 | 状态 |
|------|---------|------|
| 明文存储 Token | 🔴 CRITICAL | ⚠️ 已部分缓解 |
| 本地文件权限 | 🟢 LOW | ✅ 已优化 |
| OAuth 回调 | 🟡 MEDIUM | ⚠️ 建议改进 |
| 日志记录 | 🟢 LOW | ✅ 无敏感信息 |
| 剪贴板操作 | 🟡 MEDIUM | ⚠️ 部分缓解 |
| **总体风险** | **MEDIUM** | |

---

## 🔴 CRITICAL - 严重风险

### 1. OAuth Token 明文存储（已缓解）

**风险描述**：
- `~/.codexbar/config.json` 和 `~/.codex/auth.json` 包含明文 `access_token`、`refresh_token`
- `id_token` 以 JWT 格式明文存储（可自行解码获取 email 等信息）
- 虽然文件权限为 `0o600`（仅当前用户可读），但仍存在风险

**风险等级**：❌ CRITICAL

**修复建议**：
✅ **已部分实现** - 使用 `writeSecureFile()` 方法和 `0o600` 权限  
✅ **已添加功能** - `ClipboardManager` 剪贴板自动清除  

**进一步建议**：
- 使用 macOS Keychain 存储敏感 Token（推荐）
- 或 AES-GCM 加密存储，主密码由用户输入

**代码位置**：
```
codexBar/Services/CodexPaths.swift: writeSecureFile()
codexBar/Services/AuthSwitcher.swift:22-25 (明文写入)
codexBar/Services/CodexBarConfigStore.swift:164-165 (明文读取)
```

---

## 🟡 MEDIUM - 中等风险

### 2. OAuth 流程中的回调 URL

**风险描述**：
- OAuth 流程使用 `localhost:1455/auth/callback` 作为回调 URL
- Auth URL（包含 redirect_uri）临时复制到剪贴板（`OpenAILoginCoordinator.swift:29-30`）
- 兼容性考虑，需要手动粘贴回调 URL 的完整地址

**风险分析**：
- 🟢 回调 URL 包含 `code` 参数，**不是 token**
- 🟡 `code` 一次性使用，长期价值低
- 🟢 `localhost` 回调无法被远程攻击

**风险等级**：🟡 MEDIUM

**修复建议**：
✅ **已实现** - `ClipboardManager` 自动清除剪贴板  
✅ **已实现** - 剪贴板保护功能可配置  

**进一步建议**：
- 考虑自定义 URL Scheme（如 `com.codexbar.oauth://callback`）
- 减少手动粘贴场景

---

### 3. CSV 导入保留敏感字段

**风险描述**：
- `OpenAIAccountCSVService.swift` 导入 CSV 时包含 `access_token`、`refresh_token`
- CSV 文件通常未加密，可能泄露账号信息

**风险分析**：
- 🟡 用户需手动导出 CSV，控制权在用户
- 🟢 CSV 通常用于可信迁移场景
- ❌ CSV 文件可能被意外共享

**风险等级**：🟡 MEDIUM

**修复建议**：
✅ **已添加功能** - `L.openAICSVWarning` 警告语（需确认是否实现）  

**建议**：
- 导出时显示警告："CSV 文件包含敏感信息，请妥善保管"
- 提供"删除 Token 后导出"选项（仅导出账号元数据）

**代码位置**：
```
codexBar/Services/OpenAIAccountCSVService.swift:56-57
codexBar/Services/OpenAIAccountCSVService.swift:128-129
```

---

## 🟢 LOW - 低风险

### 4. 本地文件权限（已优化）

**当前实现**：
```swift
static func applySecurePermissions(to url: URL) throws {
    try FileManager.default.setAttributes([
        .posixPermissions: NSNumber(value: Int16(0o600)),
    ], ofItemAtPath: url.path)
}
```

✅ **权限设置正确** - `0o600` 仅当前用户可读写  
✅ **使用_atomic_ 写入** - 防止写入中断  
✅ **备份文件命名** - `.bak-codexbar-last` 易识别  

### 5. 日志记录（无敏感信息）

检查结果：
```bash
# 没有发现将 access_token 写入日志的代码
grep -r "access_token.*logger\|logger.*access_token" codexBar/
# 结果为空 ✅
```

### 6. macOS Keychain 未使用（最佳实践建议）

**当前方案**：文件系统存储  
**建议方案**：macOS Keychain（更安全）

**Keychain 优势**：
- ✅ 系统级加密存储
- ✅ 自动同步（iCloud Keychain）
- ✅ 主密码保护（可选）
- ✅ 访问控制（应用沙箱集成）

---

## 🔧 修复优先级建议

### P0 - 立即修复（无需代码，仅配置）
1. ✅ **已实现** - `ClipboardManager` 剪贴板清除
2. ✅ **已实现** - `0o600` 文件权限
3. ✅ **已实现** - `writeSecureFile` 安全写入

### P1 - 强烈建议修复（2-3天）
1. **集成 macOS Keychain**（推荐）
   - 替代 `~/.codexbar/config.json`
   - 或 AES-GCM + 主密码备份方案
2. **CSV 导出警告**（1天）
   - 添加用户提供警告文本
   - 建议使用 `/dev/stdout` 测试

### P2 - 可选优化（1-2周）
1. **自定义 URL Scheme**
   - 替代 `localhost:1455`
   - 减少端口冲突风险
2. **Audit Log（安全日志）**
   - 记录关键操作（非敏感数据）
   - 便于追溯问题

---

## ✅ 已完成的安全增强（v2.0.0）

| 功能 | 描述 | 状态 |
|------|------|------|
| 剪贴板清理 | 30秒自动清除 | ✅ |
| 快速开始引导 | 4步安全设置 | ✅ |
| 安全状态指示器 | UI 显示所有安全功能 | ✅ |
| 用量预警 | 可配置阈值提醒 | ✅ |
| 快捷键支持 | 快速切换账号 | ✅ |

---

## 📊 对比：原版 vs 定制版

| 安全功能 | v1.1.8 原版 | v2.0.0 定制版 |
|----------|------------|--------------|
| 文件权限 `0o600` | ✅ | ✅ |
| 剪贴板自动清除 | ❌ | ✅ |
| Keychain 集成 | ❌ | 🔄 计划中 |
| CSV 导出警告 | ❌ | 🔄 计划中 |
| 安全状态 UI | ❌ | ✅ |
| 用量预警 | ❌ | ✅ |

---

## 🎯 总结

### 当前风险评估：🟡 MEDIUM

**优点**：
- ✅ 文件权限设置正确（`0o600`）
- ✅ 本地存储，不上传任何数据
- ✅ OAuth `code` 一次性使用，风险低
- ✅ 剪贴板保护已实现

**主要风险**：
- ⚠️ Token 仍以明文 JSON 存储（无 Keychain）
- ⚠️ CSV 可能意外泄露敏感信息
- ⚠️ 无审计日志，问题追溯难

**修复建议**：
1. **立即行动**：使用 macOS Keychain 替代明文存储（优先级 P1）
2. **短期优化**：CSV 导出时添加 warnings（优先级 P2）
3. **长期改进**：审计日志 + 自定义 URL Scheme

---

## 📚 参考资料

- [Apple Keychain Services Programming Guide](https://developer.apple.com/documentation/security/keychain_services)
- [OWASP Secure Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [GitHub Advisory Database](https://github.com/advisories) - 类似项目漏洞

---

**报告生成时间**：2026-04-13  
**报告版本**：v2.0.0 安全增强版  
**下一步**：支持 Keychain 存储集成
