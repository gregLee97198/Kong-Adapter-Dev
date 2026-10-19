# CMTF-II Gateway / Adapter 完整开发上下文与当前现状

更新时间：2026-10-19
代码基线：`kong-nocoadapter` commit `7142390496f8c1ff6a6b70ba443d551e4caf7935`

## 1. 最终确认的业务模型

### 1.1 请求与异步处理

第三方只访问 Gateway。每次请求携带自己的 NocoBase Token；Adapter 完成鉴权、合同校验并把
请求写入 `t_api_request_staging`。Token 不写入队列，也不需要保存在持久卷。后续业务数据由
NocoBase 原生工作流在系统上下文异步处理，并按来源系统映射用户。

`create_id` 固定为 CREATE Staging 记录 ID：

- Create 成功立即返回 `Accepted` 和 `create_id`。
- 后续 Update、Query、业务状态和 Notice 都关联同一个 `create_id`。
- `intake_id`、`application_id`、非 NLA 的 `rch_id` 回填 Staging，不要求改动原业务主表保存集成字段。
- Update 被接收后异步应用；同一申请按 Staging ID 顺序处理。
- 当前业务确认不会制造“Update 刚排队同时进入 Received”的极限并发，因此不修改原生业务流程加门闩。
- 业务进入 `Received` 后的新 Update 应记录审计但不再应用。

### 1.2 人员、Home Record 与内部字段

- OP 不提交 `submitter_user_id`、Task Owner、Workflow ID、子表内部 ID、审批 comments/remarks 或
  Intake Activities。
- NLA 创建请求进入请求结果池，由已指派 Officer 打开 Draft 并按原生流程提交；测试 Officer 曾指定
  `YU Yat-chi`。
- 非 NLA 通过 `rch_no` 定位 Home Record，并取得配置的 Intake Officer；OP 是数据来源，不是业务岗位。
- LRN 只用 RCH No.，不得把 RCH No. 推断为 D No.。
- 除 NLA 外的兼容查找原则曾定义为 `create_id → rch_no → p_no`；当前规范章节若只允许 `rch_no`，
  应以 v0.8.1 的具体接口字段表为准，不得自行恢复内部 ID。

### 1.3 Checklist 与附件

- 文件始终先通过单文件上传接口上传；上传结果对外只返回 `data_id`、下载 URL、文件名和文件大小。
- Checklist 请求项使用 `position_code + attachment_id`；`attachment_id` 指向上传后的附件记录。
- NLA、LRN、CHI、AIP 共用同一套 LORCHE/LORCHD Checklist；不同 API 可返回相同 checklist ID 与
  `position_code`。
- Checklist 查询对外字段收敛为：`checklist_id`、`position_code`、`name_en`、`name_cn`、`required`。
- Checklist 的 `status` 不由 OP 提供；存在文件即视为 Submitted。
- 五类 Change 业务不使用 Checklist。
- Local Storage 与 MinIO/S3 的差异由附件记录和下载适配层处理，业务工作流只保存附件 ID，不拼存储路径。

### 1.4 Query、Notice 与状态

统一查询：`GET /v1/request/{create_id}`。目标响应只包含对外合同数据：

- `request_id`
- `create_id`
- `application_type`
- `status`
- 精简后的 `application_data`（与 OP 提交的业务内容相对应；不暴露内部 ID、Activities、Workflow 信息）
- `notices[]`

Notice 是该 `create_id` 下所有需告知第三方的记录。保留兼容字段并包含
`notice_id`、`third_party_name`、`intake_type`、`notice_type`、`status`、`content`、RCH 信息、
创建时间与 `attachments[]`。同一业务状态只形成一个 Notice；若状态需要多封信，例如 NLA Approved，
一个 Notice 内的 `attachments[]` 应同时包含 Cover Letter 与 Licence Letter。

NLA 捕捉原则：

- 有发信动作的状态由原生 Send Letter 成功且存在附件后记录。
- 无发信动作的状态由 Approval Log 或明确业务节点记录。
- `P_Number_Generated` 在产生 P No. 的状态更新节点记录。
- `Received` 需要记录到同一 `create_id`。
- `Reminding` 当前只要求人工经原生 Send Letter 发出带附件的提醒信后形成安全闭环；自动定时生成/发送另行开发。
- `Confirmed` 两个 office code 都适用；不得改原生 NLA 业务流程，只捕捉已有事件。
- `Approved` 必须 Cover Letter 与 Licence Letter 两封均登记发送后才记录。
- `Closed` 不建立驳回样本，但捕捉配置必须存在。
- OP HTTP 回调本轮不实现；先完成状态回写、Notice 记录和 Query。

CHI/LRN/其他 Application 的 Notice 工作流被明确延后，应逐业务另行配置，不影响本轮 Adapter 接收和异步建档。

## 2. 当前对外业务范围

13001 统一 Dispatcher 当前包含 12 个业务子流程：

| 业务 | CREATE/UPDATE | 备注 |
| --- | --- | --- |
| New Licence Application | 有 | NLA；不依赖 Home Record。 |
| Changing Home Information | 有 | CHI；经营者联系人以请求对象整体替换 CHI 自有联系人，不修改 Home Record。 |
| Licence Renewal | 有 | LRN；Update Checklist 使用完整清单替换。 |
| Expansion AIP | 有 | LORCHE/LORCHD 均允许。 |
| Specific Hour | 有 | SH。 |
| RP | 有 | RP。 |
| Closure Self-withdraw | 有 | 不再拆 Revoke 公共业务。 |
| Change Home Manager | 有 | 无 Checklist。 |
| Change Beds/Layout | 有 | 无 Checklist。 |
| Change Operation Mode | 有 | 对应现有 Change Home Type 业务实现。 |
| Change Directors | 有 | 无 Checklist。 |
| Change Nurse-in-Charge | 有 | 不由接口强制限制 office，OP 自行区分。 |

后续但未纳入本轮开发：RCHD Portal/EIW、Special Incident、Drug Incident、Staff Employment。

## 3. 代码现状

### 3.1 已固定代码

- 代码仓库：`git@github.com:gregLee97198/kong-nocoadapter.git`
- 分支：`main`
- commit：`7142390496f8c1ff6a6b70ba443d551e4caf7935`
- 已推送到远端。
- 本次 commit 包含 Adapter 更新、Local/211 feature gate、统一 Dispatcher/12 子流程的备份、计划、
  切换、清理、恢复和运行验收脚本，以及对应测试。
- `UPDATE_QUEUE_REQUIRED=0`：外部请求写入 Staging 后由统一工作流分发；Adapter 仍限制同一
  `create_id` 的 in-flight Update。
- `licence_renewal_update=true` 已写入 Local 和 211 配置。
- CHI 经营者整体替换只在 Local profile 开启，迁移到 211 前必须确认 13000 已具备相同工作流能力。

### 3.2 离线质量结果

本次未启动 Docker。运行命令：

```bash
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

结果：`406 passed in 28.62s`。

新增受控工作流脚本仍有 Ruff 的历史排版告警，功能测试通过；不要把“Ruff 未全绿”误写成运行逻辑失败，
也不要在迁移窗口批量自动格式化这些长脚本。

## 4. 13001 当前现状

### 4.1 已完成清理

- 69 条确认废弃的 API Staging 开发工作流已从 13001 删除。
- 删除前完整 JSON 快照位于原电脑：
  `/Users/work/noco/kong-nocoadapter-artifacts/workflow-cleanups/api-source-69-20261019T094118Z-dfcfc7b7/`
- 23 条桥接/Notice 工作流已从 `API Suorce` 分类移至 `Notice Board`。
- Prosecution 相关 NocoBase API 工作流已删除。
- 原生 NLA、Intake 业务工作流没有为了队列而修改。

### 4.2 当前统一拓扑

| 角色 | Workflow ID | 状态 |
| --- | ---: | --- |
| API Staging — External Request Dispatcher | `392938689003520` | enabled |
| New Licence Application child | `392936298250240` | enabled |
| Changing Home Information child | `392932735188992` | enabled |
| Licence Renewal child | `392932504502272` | enabled |
| Expansion AIP child | `392934299664384` | enabled |
| Specific Hour child | `392934675054592` | enabled |
| RP child | `392935272742912` | enabled |
| Closure Self-withdraw child | `392935767670784` | enabled |
| Change Home Manager child | `392937116139520` | enabled |
| Change Beds/Layout child | `392937659301888` | enabled |
| Change Operation Mode child | `392938101800960` | enabled |
| Change Directors child | `392936730263552` | enabled |
| Change Nurse-in-Charge child | `392938368139264` | enabled |

Dispatcher 使用一个 Collection Event 和多条件分支，12 个 Custom Action 子流程；每个业务子流程内部再区分
CREATE/UPDATE。红色 `Variable parsing failed` 属于设计器渲染问题，用户已要求在不影响运行赋值时跳过，
不要因此再次建立诊断工作流。

### 4.3 尚未完成的证据

- Dispatcher 和 12 个子流程在最后一次只读核对时 `executed=0`、`allExecuted=0`。
- 因此还没有证明真实 API Staging CREATE 会命中唯一分支、生成业务 Draft 并回填 ID。
- 还没有证明真实 UPDATE 会命中同一业务子流程并完整替换指定数组/Checklist。
- NLA Notice 的配置存在，但 `Confirmed`、`Approved`、`Closed` 未全部逐一做原生发信端到端验收。
- CHI Received bridge `386582576300033` 曾处于 disabled；迁移前应核对是否仍需启用，而不是直接假设完成。

## 5. 13000 与 211 当前现状

### 5.1 13000

最后一次只读核对没有找到统一 Dispatcher 或 12 个新子流程；只看到部分较早的 Notice 配置。因此必须先由用户
把 13001 已确认配置迁移到 13000，再做业务验收。不能因为数据库/应用迁移“完成”就省略 Workflow ID、enabled、
node count 和真实 Create 的回读。

### 5.2 211

- `https://119.91.104.211/health/ready` 曾返回 200。
- 无 Token 访问受保护接口返回 401，说明入口保护存在。
- ready 会检查上游认证路径，因此能证明 211 到 13000 的基础认证连通，但不能证明 12 个业务工作流已迁移。
- 当前 Compose 目标镜像基线：Gateway `kong-3.93:20260924-r3`，Adapter 的既有目标标签
  `kong-3.93-adapter:20261008-r1`。若重新构建，应使用新标签，不能覆盖并混淆旧镜像证据。

## 6. 发布阻塞项

迁移/部署前必须处理：

1. 在 13001 真实执行至少一条规范内 Create 和一条同 `create_id` Update，确认唯一 Dispatcher、唯一子流程、
   Staging 状态、业务 ID 回填和 Query。
2. 迁移统一 Dispatcher、12 子流程、Staging 字段/关联、Checklist `position_code/name_en/name_cn` 与必要 Notice
   配置到 13000。
3. 代码和 Kong YAML 仍暴露 Revoke Licence 与 Prosecution 路由；当前 13001 已删除 Prosecution 工作流，且当前
   规范不要求 Revoke。严格发布前应从 Adapter/Kong 删除，或至少在 Kong 入口明确阻断，避免“API 接收成功但无人处理”。
4. `/v1/requests/{record_id}`、`/v1/intakes`、`/v1/new-licence-applications` 等旧查询路由也应逐项对照 v0.8.1；
   只保证规范内接口，不把代码存在等同于对外承诺。
5. 13000 真实 Create/Update/Query、文件上传下载、Checklist 和 Notice 验收通过后，才部署 211。

## 7. 明确不做的事

- 不修改原生 NLA/Intake 业务流程实现队列并发门闩。
- 不将 OP Token 持久化。
- 不在本轮实现 OP 状态 HTTP 回调。
- 不把内部人员 ID、审批内容、Activities、子表 ID 暴露到规范或 Query。
- 不修改或推送 `NCSI-CM-Documents` 仓库。
- 不把历史诊断、Q3 Pilot、临时定时任务重新部署到 13001/13000。
