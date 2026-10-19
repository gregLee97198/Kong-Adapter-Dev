# CMTF-II Gateway / Adapter 开发交接库

更新日期：2026-10-19
用途：把当前代码、13001 工作流现状、验收步骤和迁移边界带到另一台电脑继续收口。

## 从这里开始

1. 阅读 [CURRENT-DEVELOPMENT-CONTEXT_20261019.md](CURRENT-DEVELOPMENT-CONTEXT_20261019.md)。
2. 按 [ACCEPTANCE-AND-PROMOTION-RUNBOOK_20261019.md](ACCEPTANCE-AND-PROMOTION-RUNBOOK_20261019.md) 执行离线、13001、13000、211 四级验收。
3. 代码以 `gregLee97198/kong-nocoadapter` 的 commit
   `7142390496f8c1ff6a6b70ba443d551e4caf7935` 为准。
4. 无法访问代码远端时，使用 `code/kong-nocoadapter-7142390-source.tar.gz`；校验值见
   [CODE-MANIFEST_20261019.md](CODE-MANIFEST_20261019.md)。

## 当前结论

当前版本是“可继续开发和迁移验收的候选版本”，不是已完成的 13000/211 发布结论。

- Adapter 相关离线测试：`406 passed`。
- 13001 已收敛为一个 API Staging Dispatcher 和 12 个业务子流程；69 条废弃开发工作流已删除。
- 统一 Dispatcher 与 12 个子流程尚无真实执行计数，必须先在 13001 做一次真实 Create/Update 验收。
- 13000 尚未发现统一 Dispatcher，需由用户完成 NocoBase 配置迁移后再验收。
- 211 `/health/ready` 曾返回 200，只说明连通和配置 Token 可用，不代表业务接口完成验收。
- 代码仍暴露 Revoke、Prosecution 等不在当前目标规范/工作流范围内的旧路由；严格发布前必须删除或在入口阻断。

## 目录

| 路径 | 内容 |
| --- | --- |
| `CURRENT-DEVELOPMENT-CONTEXT_20261019.md` | 完整业务结论、架构、代码与环境现状、阻塞项。 |
| `ACCEPTANCE-AND-PROMOTION-RUNBOOK_20261019.md` | 新电脑恢复、13001 验收、13000 迁移、211 部署与回退步骤。 |
| `CODE-MANIFEST_20261019.md` | 源码 commit、源码包校验值、测试范围及敏感信息规则。 |
| `code/` | 当前源码的无 Git 历史快照；不含运行 Token。 |
| `config/`、`delivery/`、`部署命令清单.md` | 旧 SIT 3.9.3 离线包资料，仅供历史参考，不能替代当前 211 Docker Compose 配置。 |

## 保密与大文件边界

本仓库不保存密码、Bearer Token、SSH 私钥、真实业务附件或现场数据库备份。本次也不提交
`delivery/kong-3.9.3.zip` 或新的 Docker 镜像包。账号名称可记录，密码和 Token 必须在新电脑本地
重新配置，并保持在 Git ignored 文件中。
