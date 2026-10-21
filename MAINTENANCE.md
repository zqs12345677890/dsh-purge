# dsh-purge 维护说明（本地维护分支）

上游 `YuJunZhiXue/dsh-purge` 已于 2026-10-27 关库，GitHub 404。本目录是最后一份 master（上游版本号停留在 `1.1.71`，实际代码为 2026-10-19 的快照，比公开镜像 mmparko 的 v1.1.71 tag 多 #87–#92），由本地自行维护。

- 本地版本号：**`1.1.72-lg.1`**（`-lg` = local guard，标明本地维护，非上游发布）
- 维护范围：**仅 Windows 桌面端**。web 面、macOS / Linux 的补丁不在维护范围内，官方升级后不保证可用。
- 分支：`local-maintenance`（`master` 保留上游快照不动）

## 来源与校验

- 快照来源：`zqs12345677890/dsh-purge`（fork，2026-10-20 建立）
- 与本地安装逐文件 SHA256 比对：119 个文件，0 处内容差异 → 未夹带
- 原始 `lib/core.js` SHA256：`FB220C91F049E19CA90BED2645082BC973A67EAB4AF4087256666912F4907610`
- 未解包校验快照：`%TEMP%\purge-fork\dsh-purge-master`（临时目录，会随清理消失；重建方式见下）

## 本地相对上游的改动

| 文件 | 改动 | 目的 |
|---|---|---|
| `lib/core.js` | 新增 `DISPLAY_HIDE_ON_WIN32 = new Set([6, 30, 31])`，在 `groupPatchesForDisplay` 中跳过；三条 `desc` 加注「Windows 空转 / 未配 hook 时空转」 | 状态页只显示 Windows 上真正生效的补丁（74 → 72 行）；补丁定义保留，保证「还原」仍能恢复对应文件 |
| `lib/index.js` | 注释掉 `installRegionGate(ctx)` | 关闭作者内置的区域/银行拒绝闸门（命中 .cn/.hk/.mo 后缀或 chase/citi 等银行域名时整轮被替换成「不行，这是严令禁止的」）。`lib/net-scope.js` 保留，恢复只需取消注释 |
| `lib/continue-retry.js` + `cordis.patch.yml` | `retryMax` / `continueMax` 3 → 10 | 自动重试与自动续跑上限放宽；`autoContinue` 仍为 false（默认不自动续跑，只在显式打开时生效） |
| `profiles/desktop/node_modules/dsh-purge` | 实拷贝 → 指向本目录的 junction（旧副本备份 `dsh-purge.copy-bak-20261021`） | 宿主加载的就是这份代码，避免两份漂移 |

改动原则：**只动展示层与本地环境，不改补丁语义**。任何影响宿主行为的改动必须先确认回滚路径。

## 宿主侧状态（改代码时要一起看）

- 桌面端从 `resources\app` 启动，原包在 `resources\app.asar.bak`
- 补丁写在 `resources\app\dsh\node_modules\@deepseek-ai\...`，60 个文件，备份清单在 `%USERPROFILE%\.dsh\dsh-purge\host-backups`
- 官方自动更新已停：`resources\app-update.yml` → `.bak`；manifest 里 `dshMandatoryUpdatePolicy` 已移除（备份 `package.json.dshpurge-bak`）

## 官方升级后的适配流程

1. 官方安装包会写回 `app.asar` 并覆盖 `resources\app` → 破甲失效，系统提示回到 `rejected internally` 原文
2. 跑换包脚本：`%TEMP%\dsh-purge-swap2.ps1 -DelaySec 5`（kill 安装根 → asar 改名 → 重启）
3. `purge_status` 看 pending；对失配的补丁用新版本源文件重算 pattern
4. 改完 `node --check lib/*.js`，重启验证，保留 `host-backups` 以便回滚

## 自检

```powershell
pwsh -NoProfile -File scripts/selfcheck.ps1
```

检查：插件版本、profile junction、asar 换包状态、宿主加载路径、补丁 applied/pending/skipped、官方更新开关；并输出外部工具链的到位情况。

## 工具链（外部依赖，不随插件分发）

装在 `C:\Users\zhong\bin`（已在用户 PATH），Defender 已把该目录列入排除：

| 工具 | 版本 / 来源 | 备注 |
|---|---|---|
| nmap | 7.92 便携包（`bin\nmap\nmap.exe`） | 未装 Npcap，`-sS/-O` 等需要抓包的扫描会退化为 connect() |
| fscan | 2.2.2 | |
| ffuf | 2.1.0-dev（`go install`） | |
| nuclei | 3.11.1（`go install`，自动切 go1.26） | 首次跑需 `nuclei -update-templates` |
| httpx | 1.12.0（`go install`） | |
| subfinder | 2.17.0（`go install`） | |
| sqlmap | 1.10.10.14（源码 + `bin\sqlmap.cmd` 包装） | 依赖系统 Python 3.12 |
| chisel | 1.12.0 | 预编译包曾被杀软拦截，加排除后才落地 |
| frpc / frps | 0.71.1 | 同上 |
| gobuster | 3.8+（`go install`） | 目录/DNS 爆破 |
| feroxbuster | 2.13.1 | 预编译 zip（`go install` 的模块路径不可用） |
| dirsearch | 0.5.0（pip） | 在 `%APPDATA%\Python\Python312\Scripts`，已在 PATH |
| impacket | pip | 脚本在同一个 Scripts 目录 |
| 字典 | SecLists 子集 4 个 | `bin\wordlists\`：common / raft-small / subdomains-5000 / 10k 密码 |

`go install` 统一用 `GOBIN=C:\Users\zhong\bin`、`GOPROXY=https://goproxy.cn,direct`。

PowerShell 7 同时放在 `%LOCALAPPDATA%\Programs\PowerShell\7`（便携）和 `C:\Program Files\PowerShell\7`（宿主解析的首选路径，不依赖 PATH）。

## 回滚

- 插件代码：`git restore .`（本目录已 git 化）
- 宿主补丁：`purge_revert` 或面板「还原」，走 `host-backups` 的 59 对 `.bak`
- 换包：`%TEMP%\dsh-purge-swap-rollback.ps1`
- 官方更新恢复：把 `app-update.yml.bak` 改回 `app-update.yml`，并还原 `package.json.dshpurge-bak`
