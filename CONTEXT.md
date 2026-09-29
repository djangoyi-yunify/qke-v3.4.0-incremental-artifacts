# QKE 离线升级资源准备

QKE 3.4.0 离线升级 Kubernetes 到 v1.33.4 的资源准备项目：提供更新后的
qke-installer 文件包、crane 镜像保存/推送方法与离线镜像文件。

## Language

### 核心概念

**qke-installer**:
QKE 3.4.0 内置的安装器文件包（`qke-installer-v3.4.0.tar.gz`），解压后为
`qke-installer/` 目录，含 kk 与 kubekey 依赖。
_Avoid_: 安装包、installer

**kk（KubeKey）**:
Kubernetes 集群创建/升级工具，包内版本 3.1.12（支持 k8s 最高 1.33.4）。
_Avoid_: kubekey（指依赖目录时）

**kubekey/**:
kk 的依赖二进制目录，遵循 `<类型>/<版本>/<架构>/<文件>` 布局
（etcd / cni / kube / helm）。
_Avoid_: 依赖目录

**轻量处理**:
用 tar 追加方式更新文件包（gunzip → tar -rf → gzip），只增加文件，不完整解压重打包。
_Avoid_: 重新打包、完整解压

### 存储与注册服务

**私有对象存储**:
存放 qke-installer 文件包的对象存储，默认 qingstor.com（bucket `qkeplus`）。
_Avoid_: S3、对象存储（泛指时）

**私有 OCI 注册服务**:
存放控制面镜像的注册服务，默认 registry.qingcloud.com。
_Avoid_: 内部仓库、私有仓库

**project**:
Harbor 术语，对应 OCI 标准中的 namespace，即镜像地址中注册服务后的第一段路径，
默认 `kubesphere`。
_Avoid_: 项目（中文歧义）、namespace（仅作桥接说明）

### 镜像工作流

**crane**:
镜像保存/推送工具，支持 multi-arch（全部平台）。
_Avoid_: docker

**保存**:
联网机器用 crane 将镜像保存为 OCI 布局 tar.gz（`save-images.sh`）。
_Avoid_: 导出、import

**推送**:
离线环境用 crane 将 tar.gz 推送到私有 OCI 注册服务（`load-push-images.sh`）。
_Avoid_: 导入、load

**offline-images/**:
离线镜像目录，含 12 个 multi-arch tar.gz（v1.29.15 / v1.32.8 / v1.33.4 × 4 组件）。
_Avoid_: offline-import

### 打包工作目录

**installer-work/**:
打包工作目录（非交付物），含 origin/、staging/、downloads/。
_Avoid_: 工作目录（泛指）

**origin/**:
原始文件包备份目录，只做备份，不参与打包。
_Avoid_: 备份目录（泛指）

**staging/**:
打包暂存目录，含基础包、更新后的文件包（-new）。
_Avoid_: final、helm-update

**downloads/**:
下载的 qke-installer 待追加文件目录（路径与包内一致）。
_Avoid_: 下载目录（泛指）
