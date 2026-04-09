# Codexbar OpenAI 注册/导入工作流

本目录提供一套可复现的 OpenAI 账号注册、导入、批处理与重试脚本，目标是把账号工作流稳定落在本地 `codexbar`，同时把外部 challenge、人工接管和本地可恢复故障区分清楚。

## 核心约束

- 不做任何绕过 bot/风控的改造。
- provider challenge、phone verification、about-you、manual review 只允许分类、停机、人工接管。
- 默认不切换当前 active Codexbar 账号。
- observation、summary、workflow log 不记录 `access_token`、`refresh_token`、`id_token`、验证码正文或完整 OAuth query。

## 统一账本 contract

`register/codex.csv` 已统一到 `v2` schema，核心字段如下：

| 字段 | 含义 |
| --- | --- |
| `schema_version` | 当前账本版本，现为 `v2` |
| `phase` | 当前阶段：`register` 或 `import` |
| `status` | 当前阶段结果：`pending` / `completed` / `retryable_failure` / `manual_required` / `terminal_failure` |
| `auth_method` | `password` / `email_otp` / `unknown` |
| `failure_category` | 故障或 block 分类 |
| `manual_action` | operator 下一步动作 |
| `retry_count` | 已累计自动重试次数 |
| `updated_at` | 最近写回时间 |

shared helper 为 [`register/scripts/codex_csv_state.py`](/Users/lzl/FILE/github/codexbar/register/scripts/codex_csv_state.py)，负责 legacy CSV 迁移、原子写回、candidate 选择、reconcile imported 与 retry/import eligibility 计算。

## 自动导入 gate

只有满足以下硬条件的账号才会进入自动导入：

- `phase=register`
- `status=completed`
- `auth_method=password`
- `failure_category` 为空
- `manual_action=none`

`email_otp` 注册完成不等于可自动导入。默认会保留在 CSV 中，并标记为 `manual_action=review_passwordless_account`，等待人工处理。

对已经有密码的账号，导入脚本默认保持 password 登录分支；只有显式设置 `PREFER_EMAIL_OTP_LOGIN=1` 时才会改走 OTP。

## 自动重试 vs 人工接管

自动重试只适用于本地链路类故障，例如：

- `auth_url_capture_failed`
- `cdp_race`
- `invalid_state`
- `mail_code_timeout`
- `hide_my_email_failed`

以下场景不会自动重试，会直接停在 `manual_required`：

- `captcha_challenge`
- `phone_verification`
- `about_you_block`
- `manual_review`
- 其他 provider 侧阻断

## 主要脚本

### 1. 导入已有 OpenAI 账号

```bash
OPENAI_EMAIL="you@example.com" \
OPENAI_PASSWORD="your-password" \
./register/scripts/import_openai_account_to_codexbar.sh
```

返回结构化字段，包括：

- `WORKFLOW_PHASE=import`
- `WORKFLOW_STATUS=...`
- `AUTH_METHOD=...`
- `IMPORT_FAILURE_CATEGORY=...`
- `MANUAL_ACTION=...`

### 2. 新建账号并立即尝试导入

```bash
./register/scripts/create_and_import_openai_account.sh
```

可选参数：

```bash
IMPORT_AFTER_REGISTER=0 \
./register/scripts/create_and_import_openai_account.sh
```

如果命中了 about-you 页面，默认不会盲填。只有显式设置以下参数时才允许自动填写：

```bash
ALLOW_ABOUT_YOU_AUTOFILL=1 \
ACCOUNT_NAME="Example Name" \
BIRTH_YEAR="1990" \
BIRTH_MONTH="01" \
BIRTH_DAY="08" \
./register/scripts/create_and_import_openai_account.sh
```

### 3. 先注册一批，再按 eligibility 导入

```bash
./register/scripts/create_and_import_openai_accounts_batch.sh
```

该脚本只会把满足自动导入 gate 的账号送入导入阶段；OTP-only 或人工接管账号会在注册阶段被跳过并保留在 CSV。

### 4. 只重试 helper 允许的导入失败

```bash
./register/scripts/retry_codexbar_import_from_csv.sh
```

可选参数：

```bash
EMAIL_FILTER="someone@icloud.com" \
LOGIN_INTERVAL_SECS=150 \
./register/scripts/retry_codexbar_import_from_csv.sh
```

执行顺序：

1. 先把已存在于 Codexbar 的账号 reconcile 回 `phase=import,status=completed`
2. 再选择 helper 判定为 `retryable_failure` 且未超 retry limit 的账号
3. 不会继续处理 `manual_required` / `terminal_failure`

### 5. 分段注册/导入

```bash
cd register/register-login
./01register
./02login
```

- `01register` 只负责注册，并把结构化 register 状态写入 `codex.csv`
- `02login` 只读取满足自动导入 gate 的账号，不再扫描“所有 pending 行”

### 6. wrapper 脚本

- [`register/scripts/register_and_login_10.sh`](/Users/lzl/FILE/github/codexbar/register/scripts/register_and_login_10.sh)
  - 连续执行 10 次单账号 create+import
  - 只会把 `phase=import,status=retryable_failure` 的失败加入后续 retry 队列
- [`register/scripts/register_and_login_10_v2.sh`](/Users/lzl/FILE/github/codexbar/register/scripts/register_and_login_10_v2.sh)
  - 简单 10 次 create+import wrapper，不附加二次 retry
- [`register/scripts/register_and_login_100.sh`](/Users/lzl/FILE/github/codexbar/register/scripts/register_and_login_100.sh)
  - 连续执行 N 次 create+import，并在失败摘要中打印 `phase/status/manual_action`
- [`register/scripts/register_100_accounts.sh`](/Users/lzl/FILE/github/codexbar/register/scripts/register_100_accounts.sh)
  - 以“最终 import completed 数量”为目标推进，不依赖旧 `success` 字符串

## observation 与汇总

- 注册 observation: `~/.codexbar/register-observations.jsonl`
- 导入 observation: `~/.codexbar/register-import-observations.jsonl`
- 汇总命令：

```bash
python3 ./register/scripts/summarize_import_observations.py
```

汇总输出会按：

- `phase`
- `auth_method`
- `failure_category`

聚合最近记录，并对 detail 再做一次脱敏，避免旧日志中的 URL/query 被直接回显。

## 影子账本与恢复

- repo 内主账本: `register/codex.csv`
- 全局 shadow: `~/.codexbar/register-codex.csv`
- mutation 前会先 restore/snapshot，再在主文件写回成功后同步 shadow

## 运行前提

- `/Applications/codexbar.app` 可用
- `python3`、`bash`、`swift` 可用
- `playwright-cli` 已安装
- `Mail.app` 已配置，能接收 OpenAI 验证邮件
- iCloud+ Hide My Email 可用
- 允许相关系统自动化权限

## 备注

- 保持 `PLAYWRIGHT_SESSION` 名称尽量短，避免本机 socket path 过长导致启动失败。
- 若 OpenAI 页面流转变化较大，优先补识别/分类与 stop condition，不要把 challenge 自动化成“必须通过”的目标。
