# CMTF-II SIT Kong / Adapter 3.9.3 交付

本仓库存放已构建的离线交付包、完整YAML及逐步部署命令。不需要Docker构建、pip安装或在线拉镜像。

- `config/kong.yaml`：完整Kong声明式配置，4个service、47条路由规则。
- `config/adapter.yaml`：默认使用此前.228运行基线；存储从上游NocoBase获取。
- `delivery/kong-3.9.3.zip.part*`：完整ZIP的分卷，受GitHub单文件大小限制，需先还原。
- `delivery/manifest.json`：分卷及完整ZIP SHA256。
- `restore-package.ps1`：本机还原及校验；不会部署或构建。
- `部署命令清单.md`：唯一正式部署流程，先.229后.230，.228仅需要重部署时执行。
- `接口清单.md`：包内实际路由。

在仓库目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .estore-package.ps1
```

输出 `delivery/kong-3.9.3.zip`，仅含：

```text
kong-3.9.3/kong.yaml
kong-3.9.3/adapter.yaml
kong-3.9.3/images/kong.tar.gz
kong-3.9.3/images/adapter.tar.gz
```

仓库及此ZIP不含真实Token。已有SIT升级会在服务器将旧容器有效Token和实际上游接口配置迁入现场YAML；新服务器须人工填写合法配置Token。不要提交现场含Token的YAML或ZIP。

镜像标签：kong-gateway:3.9.3、kong-adapter:3.9.3；Linux离线containerd/nerdctl，namespace cmtf2，原systemd模板负责启动/停止。

开发环境仍用/v1，SIT固定/api。保留原kong.conf、证书、CA、数据目录、已有/nocobase文件转发。不要修改外部Nginx、MinIO、Redis、NocoBase、数据库或工作流。

验证边界：.228曾实际通过导入、启动与健康路由测试；另两台须逐台现场验收。ready成功不能代替真实登录、业务及文件上传下载验收。数据库曾存在10.54.227.42:5432不可达情况，需独立确认。
