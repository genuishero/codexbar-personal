import Foundation

/// Bilingual string helper - detects system language at runtime, with user override.
enum L {
    /// nil = follow system, true = force Chinese, false = force English
    nonisolated static var languageOverride: Bool? {
        get {
            let d = UserDefaults.standard
            guard d.object(forKey: "languageOverride") != nil else { return nil }
            return d.bool(forKey: "languageOverride")
        }
        set {
            if let v = newValue {
                UserDefaults.standard.set(v, forKey: "languageOverride")
            } else {
                UserDefaults.standard.removeObject(forKey: "languageOverride")
            }
        }
    }

    nonisolated static var zh: Bool {
        if let override = languageOverride { return override }
        let lang = Locale.current.language.languageCode?.identifier ?? ""
        return lang.hasPrefix("zh")
    }

    // MARK: - Status Bar
    static var weeklyLimit: String { zh ? "周限额" : "Weekly Limit" }
    static var hourLimit: String   { zh ? "5h限额" : "5h Limit" }
    
    // MARK: - Menu Bar
    static var addAccount: String      { zh ? "添加账号"            : "Add Account" }
    static var addProvider: String     { zh ? "添加 Provider"       : "Add Provider" }
    static var bulletSeparator: String { zh ? "·" : "•" }
    static var refreshUsage: String    { zh ? "刷新用量"            : "Refresh Usage" }
    static var checkForUpdates: String { zh ? "检查更新"            : "Check for Updates" }
    static var providers: String       { zh ? "Providers"           : "Providers" }
    static var openAI: String          { zh ? "OpenAI 账号"         : "OpenAI Accounts" }
    static var addOpenAI: String       { zh ? "添加 OpenAI 账号"    : "Add OpenAI Account" }
    static var newAccount: String      { zh ? "新账号"              : "New Account" }
    static var noAccounts: String      { zh ? "暂无账号"            : "No Accounts" }
    static func menuUpdateAvailableTitle(_ version: String) -> String {
        zh ? "更新可用: \(version)" : "Update Available: \(version)"
    }
    static func menuUpdateAvailableSubtitle(_ current: String, _ latest: String) -> String {
        zh ? "当前 \(current) → 最新 \(latest)" : "Current \(current) → Latest \(latest)"
    }
    static func updateInstallActionHelp(_ version: String) -> String {
        zh ? "下载或安装 \(version)" : "Download or Install \(version)"
    }
    static var updateInstallLocationOther: String {
        zh ? "非标准路径" : "Non-standard Location"
    }
    static var updateArchitectureUniversal: String {
        zh ? "通用构建" : "Universal Build"
    }
    static var updateSignatureUnknown: String {
        zh ? "未能读取应用签名信息" : "Unable to read the app signature"
    }
    static var updateBlockerFeedRequiresGuidedDownload: String {
        zh ? "当前 feed 明确要求走引导下载/安装,不宣称自动替换闭环。" : "The current feed explicitly requires guided download/install instead of automatic replacement."
    }
    static func updateBlockerBootstrapRequired(_ currentVersion: String, _ minimumAutomaticVersion: String) -> String {
        zh
            ? "Bootstrap / Rollout Gate 未满足:\(currentVersion) 仍需先人工安装到 \(minimumAutomaticVersion) 或更高版本,自动更新闭环才从后续版本开始。"
            : "Bootstrap / rollout gate not satisfied: \(currentVersion) must first be manually upgraded to \(minimumAutomaticVersion) or later before automatic updates can be closed-loop."
    }
    static var updateBlockerAutomaticUpdaterUnavailable: String {
        zh ? "当前仓库尚未接入可用的成熟自动更新引擎。" : "A mature automatic update engine is not wired into this repository yet."
    }
    static func updateBlockerMissingTrustedSignature(_ summary: String) -> String {
        zh
            ? "当前安装缺少可用于成熟 updater 的可信签名:\(summary)"
            : "This installation lacks a trusted signature suitable for a mature updater: \(summary)"
    }
    static func updateBlockerGatekeeperAssessment(_ summary: String) -> String {
        zh
            ? "当前安装未通过 Gatekeeper / 分发前置条件:\(summary)"
            : "This installation does not satisfy the Gatekeeper / distribution prerequisites: \(summary)"
    }
    static func updateBlockerUnsupportedInstallLocation(_ pathDescription: String) -> String {
        zh
            ? "当前安装路径为 \(pathDescription),尚未纳入可自动替换的受支持范围。"
            : "The current install location is \(pathDescription), which is not yet in the supported auto-replace matrix."
    }
    static var updateErrorMissingFeedURL: String {
        zh ? "未配置更新 feed URL。" : "The update feed URL is not configured."
    }
    static func updateErrorMissingFeedURL(_ feedURL: String) -> String {
        zh ? "更新 feed URL 未配置，请在 info.plist 中设置 CodexBarUpdateFeedURL。当前值: \(feedURL)" : "Update feed URL not configured. Current value: \(feedURL)"
    }
    static func updateErrorInvalidCurrentVersion(_ version: String) -> String {
        zh ? "当前版本号无效:\(version)" : "Invalid current version: \(version)"
    }
    static func updateErrorInvalidReleaseVersion(_ version: String) -> String {
        zh ? "feed 中的版本号无效:\(version)" : "Invalid release version in feed: \(version)"
    }
    static var updateErrorInvalidResponse: String {
        zh ? "更新 feed 响应无效。" : "The update feed response is invalid."
    }
    static func updateErrorUnexpectedStatusCode(_ statusCode: Int) -> String {
        zh ? "更新 feed 返回异常状态码:\(statusCode)" : "The update feed returned status code \(statusCode)."
    }
    static func updateErrorNoCompatibleArtifact(_ architecture: String) -> String {
        zh ? "feed 中缺少适用于 \(architecture) 的安装包。" : "The feed does not contain a compatible installer for \(architecture)."
    }
    static func updateErrorFailedToOpenDownloadURL(_ url: String) -> String {
        zh ? "无法打开下载链接:\(url)" : "Failed to open the download URL: \(url)"
    }
    static var updateErrorAutomaticUpdateUnavailable: String {
        zh ? "当前构建尚未接入可执行的自动更新引擎。" : "An executable automatic update engine is not available in this build."
    }
    static var settingsWindowTitle: String { zh ? "设置" : "Settings" }
    static var settingsWindowHint: String {
        zh
            ? "左侧切换账户、用量和更新设置。窗口内的修改会先保存在草稿里,点击保存后再统一生效。"
            : "Use the sidebar to switch between account, usage, and update settings. Changes stay in a window draft until you save."
    }
    static var settingsAccountsPageTitle: String { zh ? "账户设置" : "Account Settings" }
    static var settingsUsagePageTitle: String { zh ? "用量设置" : "Usage Settings" }
    static var settingsCodexAppPathPageTitle: String { zh ? "Codex App 路径设置" : "Codex App Path" }
    static var settingsUpdatesPageTitle: String { zh ? "更新" : "Updates" }
    static var settingsUpdatesPageHint: String {
        zh
            ? "从这里检查 GitHub 上的最新稳定版本,并继续下载或安装当前可用更新。"
            : "Check the latest stable version on GitHub here, then continue to download or install the current update."
    }
    static var settingsUpdatesCurrentVersionTitle: String { zh ? "当前版本" : "Current Version" }
    static var settingsUpdatesLatestVersionTitle: String { zh ? "GitHub 最新稳定版本" : "Latest Stable Version on GitHub" }
    static var settingsUpdatesStatusTitle: String { zh ? "更新状态" : "Update Status" }
    static var settingsUpdatesUnknownVersion: String { zh ? "尚未检查" : "Not Checked Yet" }
    static var settingsUpdatesCheckAction: String { zh ? "检查 GitHub 上的最新稳定版本" : "Check the Latest Stable Version on GitHub" }
    static var settingsUpdatesInstallAction: String { zh ? "继续下载或安装更新" : "Continue Download or Install" }
    static var settingsUpdatesChecking: String { zh ? "正在检查 GitHub 上的最新稳定版本..." : "Checking the latest stable version on GitHub..." }
    static var settingsUpdatesIdle: String { zh ? "尚未发起更新检查。" : "No update check has been started yet." }
    static func settingsUpdatesUpToDate(_ version: String) -> String {
        zh ? "当前版本 \(version) 已与 GitHub 上的最新稳定版本一致。" : "The current version \(version) already matches the latest stable version on GitHub."
    }
    static func settingsUpdatesAvailable(_ currentVersion: String, _ latestVersion: String) -> String {
        zh ? "当前版本 \(currentVersion),GitHub 上可用最新稳定版本 \(latestVersion)。" : "Current version \(currentVersion); the latest stable version on GitHub is \(latestVersion)."
    }
    static func settingsUpdatesExecuting(_ version: String) -> String {
        zh ? "正在处理 \(version) 的更新动作。" : "Processing the update action for \(version)."
    }
    static func settingsUpdatesFailed(_ message: String) -> String {
        zh ? "更新失败:\(message)" : "Update failed: \(message)"
    }
    static var usageDisplayModeTitle: String { zh ? "用量显示方式" : "Usage Display" }
    static var remainingUsageDisplay: String { zh ? "剩余用量" : "Remaining Quota" }
    static var usedQuotaDisplay: String { zh ? "已用额度" : "Used Quota" }
    static var remainingShort: String { zh ? "剩余" : "Remaining" }
    static var usedShort: String { zh ? "已用" : "Used" }
    static var quotaSortSettingsTitle: String { zh ? "用量排序参数" : "Quota Sort Parameters" }
    static var quotaSortSettingsHint: String {
        zh
            ? "排序仍按用量规则计算,正在使用和运行中的账号优先。这里仅调整套餐权重换算:默认 free=1、plus=10、team=plus×1.5。"
            : "Sorting still follows quota usage rules, with active and running accounts first. These controls only adjust plan weighting: by default free=1, plus=10, and team=plus×1.5."
    }
    static var quotaSortPlusWeightTitle: String { zh ? "Plus 相对 Free 权重" : "Plus Weight vs Free" }
    static var quotaSortTeamRatioTitle: String { zh ? "Team 相对 Plus 倍数" : "Team Ratio vs Plus" }
    static var accountUsageModeTitle: String { zh ? "账号使用模式" : "Account Usage Mode" }
    static var accountUsageModeHint: String {
        zh
            ? "切换模式沿用当前逐账号生效方式;聚合模式会把 Codex 指向本地 gateway,并在后台按会话把请求路由到合适账号。"
            : "Switch mode keeps the current per-account activation flow. Aggregate mode points Codex to a local gateway that routes sessions across your OpenAI accounts."
    }
    static var accountUsageModeAggregate: String { zh ? "聚合网关" : "Aggregate Gateway" }
    static var accountUsageModeAggregateShort: String { zh ? "聚合api" : "Aggregate API" }
    static var accountUsageModeAggregateHint: String {
        zh
            ? "OpenAI OAuth 账号会被当成一个本地账号池。Codex 连接本地 gateway,gateway 按会话粘性与 failover 规则挑选账号,不再依赖重启 Codex 才切号。"
            : "Treat OpenAI OAuth accounts as one local pool. Codex talks to a local gateway, which applies session stickiness and failover instead of relying on process restarts to switch accounts."
    }
    static var accountUsageModeSwitch: String { zh ? "手动切换" : "Manual Switch" }
    static var accountUsageModeSwitchShort: String { zh ? "切换账号" : "Switch Account" }
    static var accountUsageModeSwitchHint: String {
        zh
            ? "保持当前行为:手动点账号后才切换,Codex 直接使用那个账号写入的 auth/config。"
            : "Keep the current behavior: switching only happens when you explicitly choose an account, and Codex uses that account's synced auth/config directly."
    }
    static func quotaSortPlusWeightValue(_ value: Double) -> String {
        let formatted = String(format: "%.1f", value)
        return zh ? "plus=\(formatted)" : "plus=\(formatted)"
    }
    static func quotaSortTeamRatioValue(_ value: Double, absoluteTeamWeight: Double) -> String {
        let ratio = String(format: "%.1f", value)
        let teamWeight = String(format: "%.1f", absoluteTeamWeight)
        return zh ? "team=plus×\(ratio) (= \(teamWeight))" : "team=plus×\(ratio) (= \(teamWeight))"
    }
    static var accountOrderTitle: String { zh ? "OpenAI 账号顺序" : "OpenAI Account Order" }
    static var accountOrderingModeTitle: String { zh ? "账号排序方式" : "Account Ordering" }
    static var accountOrderingModeHint: String {
        zh
            ? "可在「按用量排序」和「按手动顺序」之间切换。只有切到手动顺序时,下面的手动排序才会影响主菜单展示。"
            : "Switch between quota-based sorting and manual order. The manual list below only affects the main menu when manual order is selected."
    }
    static var accountOrderingModeQuotaSort: String { zh ? "按用量排序" : "Sort by Quota" }
    static var accountOrderingModeQuotaSortHint: String {
        zh ? "直接按当前用量权重排序,剩余可用更多的账号优先。" : "Use the current quota-weighted ranking directly, with accounts that have more usable quota first."
    }
    static var accountOrderingModeManual: String { zh ? "按手动顺序" : "Manual Order" }
    static var accountOrderingModeManualHint: String {
        zh ? "按你保存的手动顺序展示;active / running 账号仍会临时浮顶。" : "Use your saved manual order for display; active and running accounts still float to the top temporarily."
    }
    static var accountOrderHint: String {
        zh
            ? "这里定义手动顺序。只有在上方选了「按手动顺序」后它才生效;active / running 账号仍会临时浮顶。"
            : "This defines the manual order. It only takes effect when \"Manual Order\" is selected above, and active/running accounts still float to the top."
    }
    static var accountOrderInactiveHint: String {
        zh ? "当前按用量排序;你仍可预先调整手动顺序,等切到「按手动顺序」后再生效。" : "Quota sorting is currently active. You can still prepare the manual order below, and it will apply once you switch to Manual Order."
    }
    static var noOpenAIAccountsForOrdering: String { zh ? "当前没有可排序的 OpenAI 账号。" : "There are no OpenAI accounts to reorder." }
    static var moveUp: String { zh ? "上移" : "Move Up" }
    static var moveDown: String { zh ? "下移" : "Move Down" }
    static var manualActivationBehaviorTitle: String { zh ? "手动点击 OpenAI 账号时" : "When Manually Clicking an OpenAI Account" }
    static var manualActivationBehaviorHint: String {
        zh
            ? "只影响 OpenAI OAuth 账号的手动点击,不会扩展到 custom provider。"
            : "This only affects manual clicks on OpenAI OAuth accounts and does not extend to custom providers."
    }
    static var manualActivationUpdateConfigOnly: String { zh ? "仅修改配置" : "Update Config Only" }
    static var manualActivationUpdateConfigOnlyHint: String {
        zh ? "仅切换当前 active account 并同步配置,本次不新开 Codex 实例。" : "Switch the active account and sync config without launching a new Codex instance."
    }
    static var manualActivationLaunchNewInstance: String { zh ? "新开实例" : "Launch New Instance" }
    static var manualActivationLaunchNewInstanceHint: String {
        zh ? "切换账号后立刻拉起一个新的 Codex App 实例。" : "Switch the account and immediately launch a new Codex App instance."
    }
    static var manualActivationUpdateConfigOnlyOneTime: String { zh ? "仅修改配置(本次)" : "Update Config Only (This Time)" }
    static var manualActivationLaunchNewInstanceOneTime: String { zh ? "新开实例(本次)" : "Launch New Instance (This Time)" }
    static var save: String { zh ? "保存" : "Save" }
    static var codexAppPathTitle: String { zh ? "文件路径" : "Path" }
    static var codexAppPathHint: String {
        zh
            ? "手动路径优先;路径失效时会自动回退系统探测。有效路径必须是绝对路径、指向 Codex.app,并包含 Contents/Resources/codex。"
            : "A manual path takes priority, but invalid paths fall back to automatic detection. Valid paths must be absolute, point to Codex.app, and include Contents/Resources/codex."
    }
    static var codexAppPathChooseAction: String { zh ? "选择" : "Choose" }
    static var codexAppPathResetAction: String { zh ? "恢复自动探测" : "Use Auto Detection" }
    static var codexAppPathPanelTitle: String { zh ? "选择 Codex.app" : "Choose Codex.app" }
    static var codexAppPathPanelMessage: String {
        zh ? "请选择一个有效的 Codex.app。" : "Choose a valid Codex.app."
    }
    static var codexAppPathEmptyValue: String { zh ? "当前未设置手动路径" : "No manual path selected" }
    static var codexAppPathUsingManualStatus: String { zh ? "使用手动路径" : "Using the manual path" }
    static var codexAppPathInvalidFallbackStatus: String { zh ? "手动路径无效,已回退自动探测" : "Manual path is invalid; falling back to automatic detection" }
    static var codexAppPathAutomaticStatus: String { zh ? "当前使用自动探测" : "Currently using automatic detection" }
    static var codexAppPathInvalidSelection: String {
        zh
            ? "所选路径不是有效的 Codex.app。请确认它是绝对路径、名为 Codex.app,并包含 Contents/Resources/codex。"
            : "The selected path is not a valid Codex.app. Make sure it is an absolute path named Codex.app and includes Contents/Resources/codex."
    }
    static var openAICSVExportPrompt: String { zh ? "导出" : "Export" }
    static var openAICSVImportPrompt: String { zh ? "导入" : "Import" }
    static var openAICSVToolbar: String { zh ? "CSV 导入/导出" : "CSV Import/Export" }
    static var exportOpenAICSVAction: String { zh ? "导出 CSV" : "Export CSV" }
    static var importOpenAICSVAction: String { zh ? "导入 CSV" : "Import CSV" }
    static var menuUpdateAction: String { zh ? "更新" : "Update" }
    static var noOpenAIAccountsToExport: String {
        zh ? "没有可导出的 OpenAI 账号" : "No OpenAI accounts available to export"
    }
    static func openAICSVExportSucceeded(_ count: Int) -> String {
        zh ? "已导出 \(count) 个 OpenAI 账号到 CSV。" : "Exported \(count) OpenAI account\(count == 1 ? "" : "s") to CSV."
    }
    static func openAICSVImportSucceeded(
        added: Int,
        updated: Int,
        activeChanged: Bool,
        providerChanged: Bool,
        preservedCompatibleProvider: Bool
    ) -> String {
        let prefix = zh
            ? "已导入 OpenAI CSV:新增 \(added) 个,覆盖 \(updated) 个。"
            : "Imported OpenAI CSV: \(added) added, \(updated) updated."
        let suffix: String
        if preservedCompatibleProvider {
            suffix = zh ? " 当前使用 provider 保持不变。" : " The current provider was left unchanged."
        } else if providerChanged {
            suffix = zh ? " 当前 provider 已切换到 OpenAI。" : " The current provider was switched to OpenAI."
        } else if activeChanged {
            suffix = zh ? " 当前 OpenAI 账号已更新。" : " The current OpenAI account was updated."
        } else {
            suffix = zh ? " 当前 active 选择未变化。" : " The current active selection was unchanged."
        }
        return prefix + suffix
    }
    static var openAICSVEmptyFile: String { zh ? "CSV 为空,或只有表头。" : "The CSV is empty or only contains a header." }
    static var openAICSVMissingColumns: String { zh ? "CSV 缺少必需列。" : "The CSV is missing required columns." }
    static var openAICSVUnsupportedVersion: String { zh ? "不支持的 CSV 版本。" : "Unsupported CSV format version." }
    static func openAICSVInvalidRow(_ row: Int) -> String {
        zh ? "CSV 第 \(row) 行格式无效。" : "CSV row \(row) has an invalid format."
    }
    static func openAICSVMissingRequiredValue(_ row: Int) -> String {
        zh ? "CSV 第 \(row) 行缺少必填字段。" : "CSV row \(row) is missing required fields."
    }
    static func openAICSVInvalidAccount(_ row: Int) -> String {
        zh ? "CSV 第 \(row) 行的 token 校验失败。" : "CSV row \(row) failed token validation."
    }
    static func openAICSVAccountIDMismatch(_ row: Int) -> String {
        zh ? "CSV 第 \(row) 行的 account_id 校验失败。" : "CSV row \(row) failed account_id validation."
    }
    static func openAICSVEmailMismatch(_ row: Int) -> String {
        zh ? "CSV 第 \(row) 行的 email 校验失败。" : "CSV row \(row) failed email validation."
    }
    static var openAICSVDuplicateAccounts: String { zh ? "CSV 中存在重复的 account_id。" : "The CSV contains duplicate account_id values." }
    static var openAICSVMultipleActiveAccounts: String { zh ? "CSV 中包含多个 is_active=true 的账号。" : "The CSV contains multiple accounts marked as is_active=true." }
    static func openAICSVInvalidActiveValue(_ row: Int) -> String {
        zh ? "CSV 第 \(row) 行的 is_active 值无效。" : "CSV row \(row) has an invalid is_active value."
    }
    static var quit: String            { zh ? "退出"               : "Quit" }
    static var cancel: String          { zh ? "取消"               : "Cancel" }
    static var justUpdated: String     { zh ? "刚刚更新"            : "Just updated" }
    static var settings: String        { zh ? "设置"               : "Settings" }

    // MARK: - Codex Launch Probe
    static var codexLaunchProbeAppNotFound: String { zh ? "未找到 Codex.app" : "Codex.app not found" }
    static var codexLaunchProbeExecutableMissing: String { zh ? "Codex 可执行文件缺失" : "Codex executable missing" }
    static var codexLaunchProbeTimedOut: String { zh ? "启动超时" : "Launch timed out" }
    static func codexLaunchProbeFailed(_ message: String) -> String { zh ? "启动失败: \(message)" : "Launch failed: \(message)" }

    static func available(_ n: Int, _ total: Int) -> String {
        zh ? "\(n)/\(total) 可用" : "\(n)/\(total) Available"
    }
    static func minutesAgo(_ m: Int) -> String {
        zh ? "\(m) 分钟前更新" : "Updated \(m) min ago"
    }
    static func hoursAgo(_ h: Int) -> String {
        zh ? "\(h) 小时前更新" : "Updated \(h) hr ago"
    }
    // MARK: - AccountRowView
    static var accountRowViewBulletSeparator: String { zh ? "·" : "•" }
    static var reauth: String          { zh ? "重新授权"     : "Re-authorize" }
    static var useBtn: String          { zh ? "使用"         : "Use" }
    static var switchBtn: String       { useBtn }
    static var tokenExpiredMsg: String { zh ? "Token 已过期,请重新授权" : "Token expired, please re-authorize" }
    static var bannedMsg: String       { zh ? "账号已停用"   : "Account suspended" }
    static var deleteBtn: String       { zh ? "删除"         : "Delete" }
    static var deleteConfirm: String   { zh ? "删除"         : "Delete" }
    static var nextUseTitle: String    { zh ? "下一次使用"   : "Next Use" }
    static var inUseNone: String       { zh ? "未检测到正在使用的 OpenAI 会话" : "No live OpenAI sessions detected" }
    static var runningThreadNone: String { zh ? "未检测到运行中的 OpenAI 线程" : "No running OpenAI threads detected" }
    static var runningThreadUnavailable: String { zh ? "运行中状态不可用" : "Running status unavailable" }
    static var runningThreadUnavailableRuntimeLogMissing: String {
        zh ? "运行中状态不可用(未找到运行日志库)" : "Running status unavailable (runtime log database missing)"
    }
    static var runningThreadUnavailableRuntimeLogUninitialized: String {
        zh ? "运行中状态不可用(运行日志库未初始化)" : "Running status unavailable (runtime logs not initialized)"
    }

    static func inUseSessions(_ count: Int) -> String {
        zh ? "使用中 · \(count) 个会话" : "In Use · \(count) session\(count == 1 ? "" : "s")"
    }

    static func runningThreads(_ count: Int) -> String {
        zh ? "运行 \(count)" : "Running \(count)"
    }

    static func inUseSummary(_ sessions: Int, _ accounts: Int) -> String {
        if zh {
            return "使用中 · \(sessions) 个会话 / \(accounts) 个账号"
        }
        return "In Use · \(sessions) session\(sessions == 1 ? "" : "s") across \(accounts) account\(accounts == 1 ? "" : "s")"
    }

    static func runningThreadSummary(_ threads: Int, _ accounts: Int) -> String {
        if zh {
            return "运行中 · \(threads) 个线程 / \(accounts) 个账号"
        }
        return "Running · \(threads) thread\(threads == 1 ? "" : "s") / \(accounts) account\(accounts == 1 ? "" : "s")"
    }

    static func inUseUnknownSessions(_ count: Int) -> String {
        zh ? "另有 \(count) 个未归因会话" : "\(count) unattributed session\(count == 1 ? "" : "s")"
    }

    static func runningThreadUnknown(_ count: Int) -> String {
        zh ? "另有 \(count) 个未归因线程" : "\(count) unattributed thread\(count == 1 ? "" : "s")"
    }

    static var delete: String         { zh ? "删除"     : "Delete" }
    static var tokenExpiredHint: String { zh ? "Token 已过期,请重新授权" : "Token expired, please re-authorize" }
    static var accountSuspended: String { zh ? "账号已停用" : "Account suspended" }
    static var weeklyExhausted: String  { zh ? "周额度耗尽" : "Weekly quota exhausted" }
    static var primaryExhausted: String { zh ? "5h 额度耗尽" : "5h quota exhausted" }
    static var codexbar: String         { zh ? "codexbar" : "codexbar" }
    static var costLabel: String        { zh ? "成本" : "Cost" }
    static var todayCost: String        { zh ? "今天" : "Today" }
    static var last30DaysCost: String   { zh ? "过去30天" : "Last 30 days" }
    static var tokensCount: String      { zh ? "tokens" : "tokens" }
    static var noCostHistoryData: String { zh ? "无成本历史数据" : "No cost history data." }
    static var last30DaysTrend: String  { zh ? "过去30天趋势" : "Last 30 days trend" }
    static var hoverBarsForDetails: String { zh ? "悬停显示每日详情" : "Hover bars for daily details" }
    static var useBtnShort: String      { zh ? "使用" : "Use" }
    static var noOpenAIAccountAdded: String { zh ? "尚未添加 OpenAI 账号" : "No OpenAI account added." }
    static var useToolbarToAdd: String  { zh ? "使用工具栏的加号按钮添加 OpenAI OAuth 账号" : "Use the toolbar plus button to add OpenAI OAuth accounts." }
    static var openAIAccountsLabel: String { zh ? "OpenAI 账号" : "OpenAI Accounts" }
    static var providersLabel: String   { zh ? "提供商" : "Providers" }
    static var authorizationLinkNotReady: String { zh ? "授权链接未就绪" : "Authorization link not ready." }
    static var openBrowserBtn: String   { zh ? "打开浏览器" : "Open Browser" }
    static var copyLinkBtn: String      { zh ? "复制链接" : "Copy Link" }
    static var oauthPasteHint: String   { zh ? "在此粘贴 localhost 回调 URL 或 OAuth code" : "Paste the localhost callback URL or OAuth code here." }
    static var completeLoginBtn: String { zh ? "完成登录" : "Complete Login" }
    static var addProviderBtn: String   { zh ? "添加提供商" : "Add Provider" }
    static var addAccountBtn: String    { zh ? "添加账号" : "Add Account" }
    static var oauthDialogTitle: String { zh ? "OpenAI OAuth 登录" : "OpenAI OAuth" }
    static var oauthStep1: String       { zh ? "1. 在浏览器中打开授权链接" : "1. Open the authorization link in your browser." }
    static var oauthStep2: String       { zh ? "2. 完成授权" : "2. Finish authorization." }
    static var oauthStep3: String       { zh ? "3. Codexbar 会自动捕获 `http://localhost:1455/auth/callback?...`（窗口开启期间）。如果自动捕获失败，请在此粘贴完整 URL，或只粘贴 `code` 参数值" : "3. Codexbar will auto-capture `http://localhost:1455/auth/callback?...` while this window is open. If automatic capture fails, paste the full URL here. You can also paste just the `code` value." }
    static var noAccountsToAdd: String  { zh ? "添加 OpenAI 账号或创建自定义提供商" : "Add an OpenAI account or create a custom provider." }
    nonisolated static func compactResetDaysHours(_ days: Int, _ hours: Int) -> String {
        zh ? "\(days)天\(hours)时" : "\(days)d \(hours)h"
    }
    nonisolated static func compactResetHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
        zh ? "\(hours)时\(minutes)分" : "\(hours)h \(minutes)m"
    }
    nonisolated static func compactResetMinutes(_ minutes: Int) -> String {
        zh ? "\(minutes)分" : "\(minutes)m"
    }
    nonisolated static var compactResetSoon: String {
        zh ? "1分内" : "<1m"
    }

    // MARK: - TokenAccount status
    static var statusOk: String       { zh ? "正常"     : "OK" }
    static var statusWarning: String  { zh ? "即将用尽" : "Warning" }
    static var statusExceeded: String { zh ? "额度耗尽" : "Exceeded" }
    static var statusBanned: String   { zh ? "已停用"   : "Suspended" }

    // MARK: - Reset countdown
    static var resetSoon: String { zh ? "即将重置" : "Resetting soon" }
    static func resetInMin(_ m: Int) -> String {
        zh ? "\(m) 分钟后重置" : "Resets in \(m) min"
    }
    static func resetInHr(_ h: Int, _ m: Int) -> String {
        zh ? "\(h) 小时 \(m) 分后重置" : "Resets in \(h)h \(m)m"
    }
    static func resetInDay(_ d: Int, _ h: Int) -> String {
        zh ? "\(d) 天 \(h) 小时后重置" : "Resets in \(d)d \(h)h"
    }

    // MARK: - Security
    static var clipboardCleared: String { zh ? "剪贴板已清除" : "Clipboard cleared" }
    static var clipboardClearing: String { zh ? "正在清除剪贴板..." : "Clearing clipboard..." }
    
    // MARK: - Quick Start Guide (First Time)
    static var quickStartTitle: String { zh ? "快速开始指南" : "Quick Start Guide" }
    static var quickStartStep1: String { zh ? "步骤 1: 添加账号" : "Step 1: Add Account" }
    static var quickStartStep1Desc: String { zh ? "点击菜单栏的 + 按钮,选择添加账号或导入 CSV" : "Click the + button in the menu bar to add an account or import CSV" }
    static var quickStartStep2: String { zh ? "步骤 2: 选择账号" : "Step 2: Select Account" }
    static var quickStartStep2Desc: String { zh ? "在菜单中点击你想使用的账号即可切换" : "Click the account you want to use in the menu to switch" }
    static var quickStartStep3: String { zh ? "步骤 3: 配置快捷键" : "Step 3: Configure Shortcuts" }
    static var quickStartStep3Desc: String { zh ? "在设置中启用快捷键,快速切换账号" : "Enable keyboard shortcuts in Settings for quick switching" }
    static var quickStartStep4: String { zh ? "步骤 4: 设置用量预警" : "Step 4: Set Quota Warning" }
    static var quickStartStep4Desc: String { zh ? "在用量设置中配置预警阈值(默认 80%)" : "Configure warning threshold in Usage Settings (default 80%)" }
    static var skipTutorial: String { zh ? "跳过" : "Skip" }
    static var nextStep: String { zh ? "下一步" : "Next" }
    static var done: String { zh ? "完成" : "Done" }
    
    // MARK: - Security Status
    static var securityStatusLabel: String { zh ? "安全状态" : "Security Status" }
    static var encryptionEnabled: String { zh ? "🔒 加密存储" : "🔒 Encrypted Storage" }
    static var clipboardProtected: String { zh ? "🛡️ 剪贴板保护" : "🛡️ Clipboard Protected" }
    static var autoTokenRefresh: String { zh ? "🔄 自动 Token 刷新" : "🔄 Auto Token Refresh" }
    static var quotaWarning: String { zh ? "⚠️ 用量预警" : "⚠️ Quota Warning" }
    static var keyboardShortcuts: String { zh ? "⌨️ 快捷键支持" : "⌨️ Keyboard Shortcuts" }
    
    // MARK: - Quota Warning
    static var quotaWarningTitle: String { zh ? "用量预警" : "Quota Warning" }
    static func quotaWarningMessage(_ percent: Int) -> String {
        zh ? "当前用量已达到 \(percent)%,建议关注额度使用情况" : "Current usage has reached \(percent)%. Please monitor your quota usage."
    }
    
    // MARK: - Quick Switch Shortcuts
    static var shortcutGuide: String { zh ? "快捷键" : "Shortcuts" }
    static func shortcutDescription(_ number: Int, _ account: String) -> String {
        zh ? "Cmd+Shift+\(number): 切换到 \(account)" : "Cmd+Shift+\(number): Switch to \(account)"
    }
    static func shortcutSet(_ count: Int) -> String {
        zh ? "已设置 \(count) 个快捷键" : "\(count) shortcuts configured"
    }
    
    // MARK: - Token Refresh
    static var tokenRefreshing: String { zh ? "正在刷新 Token..." : "Refreshing token..." }
    static var tokenRefreshed: String { zh ? "Token 刷新成功" : "Token refreshed successfully" }
    static var tokenRefreshFailed: String { zh ? "Token 刷新失败" : "Token refresh failed" }
}
