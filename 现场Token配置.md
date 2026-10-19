

# YAML 配置与一次性切换

本仓库交付Token为空，现场从旧容器保留。下列迁移保留实际生效的API路径、上游和Token，并统一使用上游默认存储。本说明优先于部署说明中的“保留 NOCOBASE_* 环境覆盖”和“不覆盖 adapter 模板”步骤。
两份交付 YAML 已写明现场核对位置。默认值采用此前确认的 .228 基线，未声称本次重新登录读取现场。镜像不变，均为3.9.3。宿主机挂载文件是运行配置；压缩包内文件是交付副本，单改压缩包或镜像里的默认配置不会覆盖宿主机挂载。

## 配置范围

adapter.yaml：base_url、authenticator、storage.selection固定default（从上游获取默认存储）、api全部路径/两个webhook标识、response、config_token。Token空白是交付占位，必须在服务器保留真实值。
kong.yaml：services中的上游协议/端口/路径、adapter本机地址、CA引用、原有S3转发地址；顶层CA内容；upstreams.targets。/api路由已配置，route名称含v1不影响路径。
监听端口和TLS私钥路径仍由原kong.conf管理；本次不替换kong.conf、证书和systemd。
运行限制、日志、CA环境变量继续沿用容器参数，不要在YAML添加程序不支持的字段。

## 已运行节点：把实际有效配置与Token落入现场YAML

只在旧/当前adapter仍存在并可exec时执行。该步骤读取实际挂载配置和现有覆盖变量，不输出凭据。不直接用空白模板覆盖。

```bash
umask 077
nerdctl --namespace cmtf2 exec -i cmtf2-kong-adapter python - <<'PY' > /run/adapter-effective.yaml
import os, sys, yaml
from pathlib import Path
p = Path(os.getenv("NOCOBASE_CONFIG_PATH", "/app/config/nocobase.yaml"))
d = yaml.safe_load(p.read_text())
n = d["nocobase"]
for env, key in [("NOCOBASE_BASE_URL", "base_url"), ("NOCOBASE_AUTHENTICATOR", "authenticator")]:
    if env in os.environ:
        n[key] = os.environ[env]
for env, key in [("NOCOBASE_STORAGE_SELECTION", "selection"), ("NOCOBASE_STORAGE_NAME", "name"), ("NOCOBASE_ATTACHMENT_FIELD_CONTEXT", "attachment_field_context")]:
    if env in os.environ:
        n.setdefault("storage", {})[key] = os.environ[env]
token = os.getenv("NOCOBASE_CONFIG_TOKEN", "").strip()
f = os.getenv("NOCOBASE_CONFIG_TOKEN_FILE", "").strip()
if token and f:
    raise SystemExit("Conflicting token sources; stop")
if f:
    token = Path(f).read_text().strip()
token = token or n.get("config_token", "")
if not token:
    raise SystemExit("Configuration token missing; stop")
n["config_token"] = token
n["storage"] = {"selection": "default"}
sys.stdout.write(yaml.safe_dump(d, sort_keys=False, allow_unicode=True))
PY
```

上条命令成功后才执行；失败则停止，不要覆盖现场文件。

```bash
test -s /run/adapter-effective.yaml &&
cat /run/adapter-effective.yaml > /etc/cmtf2/kong-adapter/nocobase.yaml
chown root:10001 /etc/cmtf2/kong-adapter/nocobase.yaml
chmod 640 /etc/cmtf2/kong-adapter/nocobase.yaml
rm -f /run/adapter-effective.yaml
```

随后按原部署说明提取adapter.env。在停止/删除容器之前，移除已迁移到YAML的覆盖变量，保留TLS校验和CA环境变量：

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('/run/kong-3.9.3/adapter.env')
remove = {'NOCOBASE_CONFIG_TOKEN','NOCOBASE_CONFIG_TOKEN_FILE','NOCOBASE_CONFIG_PATH','NOCOBASE_BASE_URL','NOCOBASE_AUTHENTICATOR','NOCOBASE_STORAGE_SELECTION','NOCOBASE_STORAGE_NAME','NOCOBASE_ATTACHMENT_FIELD_CONTEXT'}
lines = [x for x in p.read_text().splitlines() if x.partition('=')[0] not in remove]
p.write_text(''.join(x+'\n' for x in lines))
p.chmod(0o600)
print('YAML overrides removed; secrets not printed')
PY
```

继续原说明停止、删除、create、start两个容器。保留原挂载位置。仅restart无法删除旧容器中的环境变量，因此第一次迁移必须重建adapter容器；后续改YAML只需restart。

## 后续修改及生效

编辑现场 /etc/cmtf2/kong-adapter/nocobase.yaml；不要输出包含Token的全文。修改Kong用 /etc/cmtf2/kong/kong.yml。用编辑器原位保存，保持原文件权限。不要把现场含Token文件打回公开交付包。

```bash
systemctl restart cmtf2-container@cmtf2-kong-adapter.service
systemctl restart cmtf2-container@cmtf2-kong.service
sleep 5
curl --noproxy '*' -sS -i --max-time 10 http://127.0.0.1:8080/api/health/live
curl --noproxy '*' --cacert /etc/cmtf2/kong/tls/ca.crt --resolve swductftdms91v.swd.hksarg:32443:127.0.0.1 -sS -i --max-time 10 https://swductftdms91v.swd.hksarg:32443/api/health/live
```

其他节点TLS测试使用各自FQDN。上游登录/业务验收仍按原说明，数据库不通时不判定业务通过。本次仅做文件与归档检查，未执行SIT修改或本地Docker测试。

文件存储约定：nocobase.storage.selection 使用 default；不配置 name 或 attachment_field_context。adapter 使用 config_token 调用上游 storages:getBasicInfo 获取默认存储。该逻辑不自动推断任意业务表附件字段的专属存储。Token可直接填入现场 YAML；不要保留 NOCOBASE_CONFIG_TOKEN 环境变量覆盖。
