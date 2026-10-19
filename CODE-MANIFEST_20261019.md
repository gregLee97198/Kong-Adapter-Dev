# 代码清单与完整性

## 主代码仓库

```text
repository: git@github.com:gregLee97198/kong-nocoadapter.git
branch: main
commit: 7142390496f8c1ff6a6b70ba443d551e4caf7935
short: 7142390
commit subject: feat: finalize unified API staging handoff tooling
```

该 commit 已推送。它的父级还包含 `648a18d` 的历史资料归档提交。

## 离线源码快照

```text
file: code/kong-nocoadapter-7142390-source.tar.gz
sha256: 5cde958b6a131a39a676b9c918f0f1b916c0fc735ecb06738d143bbc128f447d
size: approximately 672 KiB
```

快照由 `git archive` 生成，包含当前 commit 的：

- `app/`
- `config/`
- `deploy/`
- `docs/`
- `scripts/`
- `tests/`
- Dockerfile、Compose、requirements、pyproject 和示例环境文件

快照不含 `.git`、本地虚拟环境、Docker 镜像、运行日志、外部 artifacts、真实 Token 或密码。

## 关键配置

| 文件 | 用途 |
| --- | --- |
| `config/kong.211-dbless.yml` | 211 DB-less 路由、限流、请求大小和关联 ID。 |
| `config/compose.local-test.env` | 本地指向 13001；`UPDATE_QUEUE_REQUIRED=0`。 |
| `config/compose.online-test.env` | 211 指向 13000；`UPDATE_QUEUE_REQUIRED=0`。 |
| `config/nocobase.local-test.yaml` | 13001 feature gates；LRN Update 已开，CHI pilot 仅本地开启。 |
| `config/nocobase.211.yaml` | 13000/211 配置模板；Token 从 Docker secret 注入。 |

## 关键工作流工具

| 脚本 | 用途 |
| --- | --- |
| `backup_nocobase_api_source_workflows_13001.py` | 备份 API Source 范围工作流。 |
| `cleanup_nocobase_api_source_69_13001.py` | 精确清理确认过的 69 条旧工作流。 |
| `plan_nocobase_unified_subflow_dispatch_13001.py` | 统一 Dispatcher/12 子流程蓝图与静态验证。 |
| `execute_nocobase_unified_subflow_cutover_13001.py` | 受控切换。 |
| `execute_nocobase_unified_subflow_cleanup_13001.py` | 切换后清理。 |
| `run_nocobase_unified_subflow_runtime_acceptance_13001.py` | 单次真实 LRN 运行验收；会写 13001，必须显式确认。 |
| `resume_nocobase_unified_staging_dispatch_13001.py` | 中断后受控恢复准备过程。 |

这些脚本不是部署时全部执行的安装器。13001 当前已经有目标拓扑；另一台电脑应先只读核对，禁止重新 Prepare
一套重复工作流。

## 质量证据

2026-10-19 在不启动 Docker 的情况下：

```text
406 passed in 28.62s
```

覆盖 Adapter 主合同、Kong/portable 配置和本轮工作流备份/计划/切换/清理/恢复/验收工具。

## 已知代码差异/待处理

- Adapter 和 Kong 仍含 Revoke、Prosecution 旧路由，与当前规范/13001 工作流范围不一致。
- CHI 经营者替换 gate 在 Local 开启、211 尚未开启；必须等 13000 工作流验收。
- 新增工作流运维脚本有 Ruff 排版告警，但对应功能测试通过。
- 真实 13001 Dispatcher 执行证据尚缺，不能仅凭单元测试发布。
