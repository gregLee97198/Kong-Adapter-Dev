# 验收、迁移与部署操作步骤

本文件供另一台电脑继续收口。命令分为“只读/离线”“13001 写入验收”“13000 迁移后验收”“211 部署”。
任何一步失败即停止，不跨级继续。

## 1. 新电脑恢复代码

推荐直接克隆代码仓库：

```bash
git clone git@github.com:gregLee97198/kong-nocoadapter.git
cd kong-nocoadapter
git checkout main
git pull --ff-only
test "$(git rev-parse HEAD)" = "7142390496f8c1ff6a6b70ba443d551e4caf7935"
```

无法访问远端时，从本交接库解压：

```bash
shasum -a 256 code/kong-nocoadapter-7142390-source.tar.gz
tar -xzf code/kong-nocoadapter-7142390-source.tar.gz
cd kong-nocoadapter-7142390
```

期望 SHA-256：

```text
5cde958b6a131a39a676b9c918f0f1b916c0fc735ecb06738d143bbc128f447d
```

## 2. 安装依赖与离线验收

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
.venv/bin/pytest -q \
  tests/test_main.py \
  tests/test_kong_deployment_config.py \
  tests/test_portable_release_contract.py \
  tests/test_backup_nocobase_api_source_workflows_13001.py \
  tests/test_execute_nocobase_unified_subflow_cleanup_13001.py \
  tests/test_execute_nocobase_unified_subflow_cutover_13001.py \
  tests/test_plan_nocobase_unified_subflow_cutover_cleanup_13001.py \
  tests/test_plan_nocobase_unified_subflow_dispatch_13001.py \
  tests/test_resume_nocobase_unified_staging_dispatch_13001.py \
  tests/test_run_nocobase_unified_subflow_runtime_acceptance_13001.py
```

基线应为 `406 passed`。测试数量因后续新增测试可以增加，但不能减少或失败。

## 3. 本地 Secret 配置

真实密码和 Token 不在 Git 中。按 `secrets/README.md` 创建：

```text
secrets/nocobase_config_token.local_test   # 13001
secrets/nocobase_config_token              # 211/13000，仅在服务器
```

权限建议：

```bash
chmod 600 secrets/nocobase_config_token.local_test
git status --ignored --short secrets
```

只应显示 ignored 文件，不得显示为待提交。账号由现场确认，密码不要写入命令历史或 Markdown。

## 4. 13001 工作流只读核对

先确认以下事实，不创建诊断工作流：

- Dispatcher `392938689003520` 存在且 enabled。
- 12 个子流程 ID 与交接文档一致且 enabled。
- Dispatcher 只有一个 Collection Event；路由节点是 multi-conditions；每个业务只有一个 Custom Action 子流程。
- 旧 69 条工作流不存在。
- Prosecution 工作流不存在。
- Notice 工作流属于 `Notice Board` 分类，不属于 `API Suorce`。

可使用当前仓库的只读/计划工具，但在运行前先执行 `--help`；带 `--apply`、`--run`、`--confirm` 的参数都视为写入。

## 5. 13001 最小真实验收

不要跑批量数据。文件逐个上传，Checklist 只提交附件 ID。

### 5.1 基础接口

1. `GET /health/ready` 返回 200。
2. 获取 Token；错误密码返回 401。
3. 上传一个小型 PDF：响应含 `data_id`、URL、文件名、大小。
4. 下载刚上传的 `data_id`：内容长度和 MIME 正确。
5. 分别查询 LORCHE、LORCHD Checklist；字段只包含规范字段，关键 Position Code 可用。

### 5.2 一条 Create

建议先用 NLA：

1. 生成唯一 `request_id`，格式建议 `OP-NLA-YYYYMMDD-HHMMSS-01`。
2. Request Body 不带内部人员 ID、Task Owner、Activities、子表 ID 或独立 `attachment_ids`。
3. Checklist 用 `position_code + attachment_id`。
4. HTTP 返回 `accepted=true`、同一 `request_id`、`create_id`、`application_type`、`status=Accepted`。
5. Staging 只产生一条 CREATE，来源为 OP，状态进入统一 Dispatcher。
6. Dispatcher 执行计数增加一次，只命中 NLA 子流程；其他 11 个子流程不执行。
7. 业务 Draft 创建一次，回填 `intake_id`、`application_id`；不出现重复主表/子表/附件。
8. Officer 可在原生页面打开 Draft。

### 5.3 同一个 create_id 的 Update

1. 在仍为 Accepted 时提交一次 Update。
2. HTTP 接收成功，Staging 新增 UPDATE，但公共 `create_id` 仍为原 CREATE ID。
3. 只命中 NLA 子流程 UPDATE 分支。
4. 请求中出现的数组按完整清单替换；未提交的类别保持不变；空数组表示清空。
5. Checklist 关联只更新对应 attachment ID，不重新上传文件、不创建循环 Details。
6. Query 返回最后一次成功 Update 后的业务数据。
7. 将业务推进至 Received 后再 Update，应记录但不应用，响应合同按当前规范验证。

若执行 LRN Checklist 验收，必须额外检查没有再次出现历史上单条 Checklist 生成数百 Details 的循环故障。

### 5.4 Query 与 Notice

1. 业务状态节点发生后，使用 `GET /v1/request/{create_id}` 查询。
2. 响应的 `request_id/create_id/application_type/status` 正确。
3. `application_data` 无内部人员 ID、Workflow ID、Activities、子表 ID和无意义空字段。
4. `notices[]` 是列表；同一状态最多一个 Notice。
5. Notice 有 `content`、状态、类型及附件数组；Approved 如发生，应在一个 Notice 内包含两份信件附件。
6. 附件 ID 可通过下载接口取得真实文件。

## 6. 全规范接口矩阵

只对 v0.8.1 中存在的接口做发布承诺。每个业务至少执行：合同校验、Create、Query；有 Update 的再执行 Update。

| 业务 | Create | Update | Checklist |
| --- | --- | --- | --- |
| NLA | 必测 | 必测 | LORCHE/LORCHD |
| CHI | 必测 | 必测，经营者整体替换 | 与 NLA 共用 |
| LRN | 必测 | 必测，Checklist 完整替换 | 与 NLA 共用 |
| AIP | 必测 | 必测 | 与 NLA 共用 |
| SH | 必测 | 必测 | 依规范 |
| RP | 必测 | 必测 | 依规范 |
| Closure Self-withdraw | 必测 | 必测 | 依规范 |
| 5 类 Change | 各必测 | 各必测 | 无 |

Revoke 和 Prosecution 不在该矩阵；存在的 Adapter/Kong 旧路由必须先删除或阻断。

## 7. 13001 → 13000 迁移验收

迁移由用户执行。必须同时迁移：

- `t_api_request_staging` 新字段、关联和索引；
- Dispatcher、12 子流程及其 enabled 状态；
- 业务子流程引用的 collection/field UID；
- Checklist 的 `f_position_code`、`name_en`、`name_cn` 与共用目录关系；
- 文件/附件 relation；
- 本轮要求的 NLA Notice/Approval Log/Send Letter 旁路配置；
- 来源系统到用户/角色的映射。

迁移后先在 13000 后台做只读核对，再临时从受控客户端执行 5.1～5.4。任何 Workflow UID/字段 UID 不存在、
Variable 解析失败导致实际取值为空、Dispatcher 执行数不增加或重复建档，都视为失败，不能部署 211。

## 8. 211 部署命令

仅在 13000 验收通过后执行。服务器目录按现有部署：

```bash
cd /Servers/Kong-db-less
git status --short
git pull --ff-only origin main
git rev-parse HEAD
```

必须看到目标 commit 或后续已批准 commit。先校验 Compose：

```bash
docker compose \
  --env-file config/compose.online-test.env \
  -f docker-compose.yml \
  config --quiet
```

使用新镜像标签再构建 Adapter，避免覆盖旧证据。若 compose env 已更新标签：

```bash
docker compose \
  --env-file config/compose.online-test.env \
  -f docker-compose.yml \
  build --no-cache kong-nocoadapter

docker compose \
  --env-file config/compose.online-test.env \
  -f docker-compose.yml \
  up -d --force-recreate kong-nocoadapter kong-gateway

docker compose \
  --env-file config/compose.online-test.env \
  -f docker-compose.yml \
  ps
```

不要因 13000 启动未完成而反复重建镜像。Adapter unhealthy 时先查看：

```bash
docker compose \
  --env-file config/compose.online-test.env \
  -f docker-compose.yml \
  logs --tail=200 kong-nocoadapter
```

## 9. 211 验收顺序

```bash
curl -k -i https://127.0.0.1/health/ready
```

然后按顺序验证：

1. 外部 `https://119.91.104.211/health/ready` 200。
2. 无 Token 的受保护接口 401。
3. 正确 Token 的 Checklist 查询。
4. 单文件上传和下载。
5. 一条 NLA Create，记录 `request_id/create_id`。
6. 13000 后台确认只执行唯一 Dispatcher/子流程并生成 Draft。
7. 同 `create_id` Update。
8. 业务状态变更后的 Query 与 Notice。
9. 其余 v0.8.1 业务矩阵逐项验收。

健康检查通过不等于业务通过；必须保存脱敏的请求/响应、HTTP 状态、Staging ID、Workflow execution ID、
业务 Application ID 与 Query 结果作为验收记录。

## 10. 回退原则

- 代码：切回部署前 commit 和旧镜像标签。
- Gateway：恢复部署前已验证的 DB-less YAML。
- NocoBase：禁用新 Dispatcher/子流程，恢复迁移前备份中的旧工作流版本；不要删除本次真实业务数据。
- 若出现重复触发，第一动作是停止新 API 入站或禁用统一 Dispatcher，不能继续创建诊断定时任务。
- 回退后用原 `create_id` 核查 Staging/业务/附件是否需要人工修复，并留下审计记录。
