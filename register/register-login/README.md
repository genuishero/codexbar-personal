# Register & Login

分段执行 OpenAI 账号注册 + Codexbar 登录流程。

## 流程

```
01register  →  生成 iCloud 邮箱 → 注册 OpenAI  →  写入 codex.csv (phase=register, status=...)
02login     →  只读取“可自动导入”的账号  →  登录 Codexbar  →  更新为 (phase=import, status=completed)
```

## 用法

### 第一步：注册

```bash
# 默认注册 10 个
./01register

# 注册 50 个
./01register 50

# 注册 100 个，间隔 180 秒
COUNT=100 INTERVAL_SECS=180 ./01register
```

### 第二步：登录导入 Codexbar

```bash
# 登录所有满足自动导入 gate 的账号
./02login

# 只登录 20 个
./02login 20

# 登录 50 个，间隔 180 秒
COUNT=50 INTERVAL_SECS=180 ./02login

# 只处理指定邮箱
EMAIL_FILTER="xxx@icloud.com" ./02login 1
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `COUNT` | 注册/登录数量 | `10`（注册），全部满足自动导入 gate 的账号（登录） |
| `INTERVAL_SECS` | 每次操作间隔秒数 | `10`（注册），`150`（登录） |
| `CSV_PATH` | codex.csv 路径 | `../codex.csv` |
| `EMAIL_FILTER` | 仅处理指定邮箱（仅 02login） | 无 |

## 观测与失败分类

- 注册侧会写 `~/.codexbar/register-observations.jsonl`
- 导入侧会写 `~/.codexbar/register-import-observations.jsonl`
- provider challenge / phone / about-you / manual review 会进入 `manual_required`
- 只有本地链路类问题才会进入 `retryable_failure`
- 汇总命令：

```bash
python3 ../scripts/summarize_import_observations.py
```

## CSV 关键字段

| 字段 | 含义 |
|------|------|
| `schema_version` | 当前账本 schema，现为 `v2` |
| `phase` | 当前阶段：`register` 或 `import` |
| `status` | 当前阶段结果：`pending` / `completed` / `retryable_failure` / `manual_required` / `terminal_failure` |
| `auth_method` | 认证方式：`password` / `email_otp` / `unknown` |
| `failure_category` | 失败或 block 分类 |
| `manual_action` | 当前需要 operator 做什么 |
| `retry_count` | 已累计自动重试次数 |

## 自动导入规则

- 只有同时满足以下条件的账号会进入 `02login`：
  - `phase=register`
  - `status=completed`
  - `auth_method=password`
  - `failure_category` 为空
  - `manual_action=none`
- `email_otp` 注册成功不等于可自动导入；默认会保留在 CSV 中，等待人工接管。
- 对已满足自动导入 gate 且已有密码的账号，`02login` 触发的导入默认保持 password 分支，不会再因为页面出现 OTP 入口而自动切走。

## 自动重试规则

- `retry_codexbar_import_from_csv.sh` 只会挑选 helper 认定为可自动重试的账号。
- 典型可自动重试分类：
  - `cdp_race`
  - `auth_url_capture_failed`
  - `invalid_state`
  - `mail_code_timeout`
- 以下分类不会自动重试，会直接停在 `manual_required`：
  - `captcha_challenge`
  - `phone_verification`
  - `about_you_block`
  - `manual_review`
