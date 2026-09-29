# QKE 3.4.0 离线升级 Kubernetes 到 v1.33.4 的资源准备

> 本资源包用于：为 QKE 3.4.0 提供新的 `qke-installer-v3.4.0.tar.gz` 文件包，
> 支持通过**手动升级**的方式将 Kubernetes 离线升级到 **v1.33.4**；同时提供升级
> 所需的 **镜像离线保存与推送方法**（crane）与 **离线镜像文件**，方便用户在离线环境使用。

---

## 一、项目介绍

QKE（青云 Kubernetes 引擎）3.4.0 内置的 `qke-installer-v3.4.0.tar.gz` 中，
KubeKey（kk）版本为 3.1.7，最高仅支持 Kubernetes 1.31.2，无法将集群升级到
1.33.4。本资源包完成以下工作：

1. **升级 kk 到 3.1.12**（支持 k8s 最高 1.33.4），并补齐 kk 3.1.12 在创建/升级
   集群时需要的依赖二进制（etcd、calicoctl、kubelet/kubeadm/kubectl、helm），
   重新打包生成新的 `qke-installer-v3.4.0.tar.gz`，供离线环境直接使用。
2. **补齐控制面镜像**：将 `kube-apiserver`、`kube-controller-manager`、
   `kube-scheduler`、`kube-proxy` 的 v1.29.15 / v1.32.8 / v1.33.4 镜像（multi-arch）
   保存为离线 tar.gz 并推送到私有 OCI 注册服务（默认 `registry.qingcloud.com/kubesphere/`），提供离线
   保存与推送方法。

### 1.1 使用工具

| 工具 | 用途 | 安装 | 使用 |
| --- | --- | --- | --- |
| **crane** | 镜像保存/推送（multi-arch） | 下载 [go-containerregistry](https://github.com/google/go-containerregistry/releases) 二进制至 `/usr/local/bin/crane` | `crane pull --platform all --format oci <镜像> <目录>`；`crane push <目录> <私有OCI注册服务>/<项目>/<镜像>` |
| **rclone** | 对象存储上传/下载 | 下载 [rclone](https://rclone.org/downloads/) 二进制，配置文件放默认位置 `~/.config/rclone/rclone.conf` | `rclone copyto <本地> qingstor:<bucket>/<key>` |
| **qsctl** | 对象存储上传/下载（青云官方） | 下载 [qsctl](https://github.com/qingstor/qsctl/releases)，配置文件放默认位置 `~/.qingstor/config.yaml` | `qsctl cp <本地> qs://<bucket>/<key>` |

> **私有存储约定**：本文中 `qke-installer` 文件包存放在**私有对象存储**，控制面镜像
> 推送到**私有 OCI 注册服务**。默认私有对象存储为 **qingstor.com**（青云 QingStor），
> 默认私有 OCI 注册服务为 **registry.qingcloud.com**（青云 Harbor），默认 bucket 为
> **qkeplus**。私有 OCI 注册服务中的 **project**（Harbor 术语，对应 OCI 标准中的
> **namespace**，即镜像地址中注册服务后的第一段路径）默认为 **kubesphere**。
> 若使用其他私有存储，替换对应地址即可。

### 1.2 配置文件示例

**rclone**（默认位置 `~/.config/rclone/rclone.conf`）：

```ini
[qingstor]
type = qingstor
access_key_id = <你的 Access Key ID>
secret_access_key = <你的 Secret Access Key>
zone = pek3b
```

**qsctl**（默认位置 `~/.qingstor/config.yaml`）：

```yaml
access_key_id: '<你的 Access Key ID>'
secret_access_key: '<你的 Secret Access Key>'
zone: 'pek3b'
host: 'qsstor.com'
port: 443
protocol: 'https'
```

> 默认 bucket 名称为 **qkeplus**，`qke-installer-v3.4.0.tar.gz` 存放于该 bucket 下。

## 二、升级思路

| 步骤 | 方式 | 升级路径 | 说明 |
| --- | --- | --- | --- |
| 1 | QKE Web 控制台 | k8s **1.27.10 → 1.31.2** | 使用 QKE 控制台在线/离线升级 |
| 2 | KubeKey（kk） | k8s **1.31.2 → 1.33.4** | 在 **master1** 节点上使用 kk 升级 |

> 说明：QKE 控制台内置 kk 3.1.7 最高支持 1.31.2，因此 1.31.2 之后的升级需使用
> 升级后的 kk 3.1.12 在 master1 节点手动执行。

### kk 升级命令

在 master1 节点执行（离线环境，使用包内已补齐的依赖与私有 OCI 注册服务已推送的镜像）：

```bash
kk upgrade -f <your-config-file> --skip-pull-images --skip-dependency-check
```

- `--skip-pull-images`：跳过拉取镜像（使用私有 OCI 注册服务，默认
  `registry.qingcloud.com/kubesphere/` 已推送的镜像）
- `--skip-dependency-check`：跳过依赖检查（使用 `qke-installer/kubekey/` 已补齐的
  依赖二进制，如 etcd、calicoctl、kubelet/kubeadm/kubectl、helm）

## 三、需要准备的文件和理由

### 3.1 qke-installer 文件包所需文件

| 文件 | 版本 | 理由 |
| --- | --- | --- |
| kubekey（kk） | **3.1.12** | 该版本支持的 k8s 最高版本是 1.33.4；原有 kk 3.1.7 仅支持到 1.31.2 |
| calicoctl | **3.27.4** | kk 3.1.12 在创建或升级 k8s 集群时，会自动下载（如果文件不存在） |
| etcd | **3.5.24** | kk 3.1.12 在创建或升级 k8s 集群时，会自动下载（如果文件不存在） |
| k8s 二进制（kubelet/kubeadm/kubectl） | **1.33.4 / 1.32.8 / 1.29.15** | kk 3.1.12 在创建或升级 k8s 集群时，会自动下载（如果文件不存在） |
| helm | **3.18.5** | kk 3.1.12 在创建 k8s 集群时，会自动下载（如果文件不存在） |

### 3.2 离线镜像

| 文件 | 版本 | 理由 |
| --- | --- | --- |
| 控制面镜像（kube-apiserver / kube-controller-manager / kube-scheduler / kube-proxy） | **1.33.4 / 1.32.8 / 1.29.15** | 升级逐 minor 版本进行，节点需从**私有 OCI 注册服务**拉取各版本控制面镜像；离线环境需预先保存并推送（12 个 multi-arch tar.gz，见 `offline-images/`） |

## 四、文件组织

| 目录/文件 | 说明 |
| --- | --- |
| `installer-work/downloads/` | 下载的 qke-installer 待追加文件（`kk`、`kubekey/`），布局见 4.1 |
| `offline-images/` | 镜像离线保存/推送所需文件（12 个 multi-arch tar.gz，v1.29.15 / v1.32.8 / v1.33.4 × 4 组件） |
| `scripts/` | 脚本专用目录 |
| `README.md` 及根目录文档 | 文档一律放到项目根目录 |

### 4.1 qke-installer 目录与文件布局

`qke-installer-v3.4.0.tar.gz` 解压后为 `qke-installer/` 目录，其布局如下，
供 kk 3.1.12 在创建/升级集群时使用。下载脚本将待追加文件下载到
`installer-work/downloads/`（路径与包内一致）。**新增文件需追加到对应路径**
（见第七节）。

```
qke-installer/
├── kk                                          # kubekey 3.1.12 二进制
└── kubekey/                                    # KubeKey 依赖二进制
    ├── etcd/v3.5.24/amd64/etcd-v3.5.24-linux-amd64.tar.gz
    ├── cni/v3.27.4/amd64/calicoctl
    ├── kube/
    │   ├── v1.29.15/amd64/{kubeadm,kubelet,kubectl}
    │   ├── v1.32.8/amd64/{kubeadm,kubelet,kubectl}
    │   └── v1.33.4/amd64/{kubeadm,kubelet,kubectl}
    └── helm/v3.18.5/amd64/helm
```

`kubekey/` 子目录遵循 KubeKey 约定：**`<类型>/<版本>/<架构>/<文件>`**。

| 类型 | 说明 | 文件 |
| --- | --- | --- |
| `etcd` | etcd 服务端 | `etcd-v3.5.24-linux-amd64.tar.gz` |
| `cni` | 网络插件（calico） | `calicoctl` |
| `kube` | k8s 组件二进制 | `kubeadm`、`kubelet`、`kubectl` |
| `helm` | Helm 客户端 | `helm` |

> 说明：kk 3.1.12 在创建/升级集群时，会到其 workDir（`<kk 二进制目录>/kubekey/`）
> 下按上述路径查找依赖；文件不存在时自动联网下载。因此离线环境需将解压后的
> `qke-installer/kubekey/` 放到 kk 二进制所在目录下，并保证路径与上表一致。

## 五、目录结构

```
qke-artifacts/
├── README.md                                  # 本综合文档
├── 更新qke-installer-v3.4.0文件包操作文档.md    # 文件包更新操作文档（参考）
├── 镜像离线保存与推送操作文档.md                # 镜像离线保存与推送详细文档（参考）
├── 青云公有云环境调整记录.md                    # 青云公有云环境调整记录（参考）
│
├── offline-images/                            # 3.2 离线镜像（12 个 multi-arch tar.gz）
│   ├── kube-apiserver-v1.29.15.tar.gz
│   ├── kube-apiserver-v1.32.8.tar.gz
│   ├── kube-apiserver-v1.33.4.tar.gz
│   ├── kube-controller-manager-v1.29.15.tar.gz
│   ├── kube-controller-manager-v1.32.8.tar.gz
│   ├── kube-controller-manager-v1.33.4.tar.gz
│   ├── kube-scheduler-v1.29.15.tar.gz
│   ├── kube-scheduler-v1.32.8.tar.gz
│   ├── kube-scheduler-v1.33.4.tar.gz
│   ├── kube-proxy-v1.29.15.tar.gz
│   ├── kube-proxy-v1.32.8.tar.gz
│   └── kube-proxy-v1.33.4.tar.gz
│
├── scripts/                                   # 脚本专用目录
│   ├── save-images.sh                         # 联网机器：crane 保存 multi-arch 镜像为 OCI tar.gz
│   ├── load-push-images.sh                    # 离线环境：crane 推送镜像到私有 OCI 注册服务
│   ├── download-installer-files.sh            # 联网机器：下载 qke-installer 待追加文件并校验
│   ├── verify-checksums.sh                    # 校验 qke-installer 文件 SHA256（含 helm v3.18.5）
│   └── append-to-installer.sh                 # 轻量打包：向 tar.gz 追加文件（gunzip → tar -rf → gzip）
│
└── installer-work/                            # 打包工作目录（非交付物）
    ├── origin/
    │   └── qke-installer-v3.4.0.tar.gz        # 原始文件包（备份，只做备份）
    ├── staging/                               # 打包暂存目录
    │   ├── qke-installer-v3.4.0.tar.gz        # 基础包（从 origin 拷贝）
    │   ├── qke-installer-v3.4.0.tar           # 半解压文件（gunzip 后、tar 追加前，可选）
    │   └── qke-installer-v3.4.0-new.tar.gz    # 更新后的文件包
    └── downloads/                             # 下载的 qke-installer 待追加文件（4.1 布局）
        └── qke-installer/
            ├── kk                             # kubekey 3.1.12 二进制
            └── kubekey/                       # KubeKey 依赖二进制（<type>/<version>/<arch>/<file>）
                ├── cni/v3.27.4/amd64/calicoctl
                ├── etcd/v3.5.24/amd64/etcd-v3.5.24-linux-amd64.tar.gz
                ├── helm/v3.18.5/amd64/helm
                └── kube/
                    ├── v1.29.15/amd64/{kubeadm,kubelet,kubectl}
                    ├── v1.32.8/amd64/{kubeadm,kubelet,kubectl}
                    └── v1.33.4/amd64/{kubeadm,kubelet,kubectl}
```

> **`installer-work/` 说明**：`installer-work/` 是**打包工作目录（非交付物）**。
> - `origin/`：原始文件包（备份），**只做备份**，不参与打包。操作前需将当前线上包
>   保存到此目录（命令见第七节）。
> - `staging/`：打包暂存目录，存放基础包（从 `origin/` 拷贝）、更新后的文件包
>   （`-new`）及半解压文件（`qke-installer-v3.4.0.tar`）。
> - `downloads/`：`download-installer-files.sh` 下载的 qke-installer 待追加文件（布局见 4.1），
>   供 `append-to-installer.sh` 追加使用。

## 六、文件获取

### 6.1 下载地址

| 组件 | 版本 | 下载地址 |
| --- | --- | --- |
| kubekey | 3.1.12 | `https://github.com/kubesphere/kubekey/releases/download/v3.1.12/kubekey-v3.1.12-linux-amd64.tar.gz` |
| etcd | 3.5.24 | `https://github.com/coreos/etcd/releases/download/v3.5.24/etcd-v3.5.24-linux-amd64.tar.gz` |
| kubeadm/kubelet/kubectl | 1.29.15 | `https://dl.k8s.io/release/v1.29.15/bin/linux/amd64/{kubeadm,kubelet,kubectl}` |
| kubeadm/kubelet/kubectl | 1.32.8 | `https://dl.k8s.io/release/v1.32.8/bin/linux/amd64/{kubeadm,kubelet,kubectl}` |
| kubeadm/kubelet/kubectl | 1.33.4 | `https://dl.k8s.io/release/v1.33.4/bin/linux/amd64/{kubeadm,kubelet,kubectl}` |
| calicoctl | 3.27.4 | `https://github.com/projectcalico/calico/releases/download/v3.27.4/calicoctl-linux-amd64` |
| helm | 3.18.5 | `https://get.helm.sh/helm-v3.18.5-linux-amd64.tar.gz` |
| 控制面镜像 | 1.29.15 / 1.32.8 / 1.33.4 | `registry.k8s.io/kube-{apiserver,controller-manager,scheduler,proxy}:<版本>` |

### 6.2 校验值（SHA256）

校验值来源：KubeKey v3.1.12 源码 `version/components.json`。

| 文件 | SHA256 |
| --- | --- |
| `kubekey/kube/v1.29.15/amd64/kubeadm` | `d0744fbaa1e67fc65c4a3409f083e01a4ede58181c759b2feeb08b1ef10d6201` |
| `kubekey/kube/v1.29.15/amd64/kubelet` | `cd0228a5820f98bbb6371344e5d6645f6486d767c30f927a1d0ec8d17eca4da5` |
| `kubekey/kube/v1.29.15/amd64/kubectl` | `3473e14c7b024a6e5403c6401b273b3faff8e5b1fed022d633815eb3168e4516` |
| `kubekey/kube/v1.32.8/amd64/kubeadm` | `da4cc996800db14f82fce8813caa55be318e52ef69d82e50e728ef4cfa18b69f` |
| `kubekey/kube/v1.32.8/amd64/kubelet` | `7dfca4da9cdf592c0f70800e09fb42553765bc0951cade3d6e0c571daf3f23ee` |
| `kubekey/kube/v1.32.8/amd64/kubectl` | `0fc709a8262be523293a18965771fedfba7466eda7ab4337feaa5c028aa46b1b` |
| `kubekey/kube/v1.33.4/amd64/kubeadm` | `a109ebcb68e52d3dd605d92f92460c884dcc8b68aebe442404af19b6d9d778ec` |
| `kubekey/kube/v1.33.4/amd64/kubelet` | `109bd2607b054a477ede31c55ae814eae8e75543126dc4cea40b04424d843489` |
| `kubekey/kube/v1.33.4/amd64/kubectl` | `c2ba72c115d524b72aaee9aab8df8b876e1596889d2f3f27d68405262ce86ca1` |
| `kubekey/etcd/v3.5.24/amd64/etcd-v3.5.24-linux-amd64.tar.gz` | `042497e2ddcee06f22e5d486d81f58affa26b53ee423e2a6aaca3d3ea98c8191` |
| `kubekey/cni/v3.27.4/amd64/calicoctl` | `84f2bd29ef7b06e85a2caf0b6c6e0d3da5ab5264d46b360e6baaf49bbc3b957d` |
| `kubekey/helm/v3.18.5/amd64/helm` | `0f4167894a59151cc45564642ca1c7d22b251f46055cc96cf2b3f1fda8c22b97` |

校验命令：

```bash
bash scripts/verify-checksums.sh
```

## 七、文件打包（生成新的 qke-installer-v3.4.0.tar.gz）

> 以下命令均在**项目根目录**执行（`cd <项目根目录>`），脚本与工具使用相对路径。

操作分为**互联网侧操作**与**离线环境侧操作**。

### 7.1 互联网侧操作

**下载需要追加的文件**（kk 3.1.12、etcd、calicoctl、kube 二进制、helm v3.18.5），
放入 `installer-work/downloads/`（路径与包内一致，带 `qke-installer/` 前缀）。
脚本内部已按 kk 3.1.12 官方 `version/components.json` 逐一校验 SHA256。

```bash
bash scripts/download-installer-files.sh
```

### 7.2 离线环境侧操作

#### 7.2.1 备份私有对象存储中的 qke-installer

将私有对象存储中存放的 `qke-installer-v3.4.0.tar.gz` 备份：

**下载到本地**（`installer-work/origin/`，只做备份）：

```bash
mkdir -p installer-work/origin/
rclone copy qingstor:qkeplus/qke-installer-v3.4.0.tar.gz installer-work/origin/
```

**对象存储内备份（复制并重命名）**：

```bash
rclone copyto \
  qingstor:qkeplus/qke-installer-v3.4.0.tar.gz \
  qingstor:qkeplus/qke-installer-v3.4.0.tar.gz.$(date +%Y%m%d)
```

> **注意**：备份操作需小心，避免反复操作覆盖原始备份。
> - `origin/` 只做备份：若已存在原始包，`rclone copy` 会覆盖，请勿重复执行。
> - 对象存储内备份以日期命名（`$(date +%Y%m%d)`）：同一天重复执行会覆盖同名备份，
>   建议确认备份对象已存在后再继续后续操作。

#### 7.2.2 校验下载的文件

```bash
bash scripts/verify-checksums.sh
```

#### 7.2.3 制作新的 qke-installer 文件包

**从备份拷贝基础包到 staging/**：

```bash
mkdir -p installer-work/staging/
cp installer-work/origin/qke-installer-v3.4.0.tar.gz installer-work/staging/
```

**轻量处理：tar 追加并压缩**（在 staging/ 中操作）：

```bash
bash scripts/append-to-installer.sh \
  installer-work/staging/qke-installer-v3.4.0.tar.gz \
  installer-work/downloads \
  installer-work/staging/qke-installer-v3.4.0-new.tar.gz
```

> **无需手动删除旧文件**：脚本在临时目录生成中间 tar 并自动清理（不读取/不写入
> staging/ 中的半解压 `qke-installer-v3.4.0.tar`）；输出用 `mv` 覆盖已有的
> `qke-installer-v3.4.0-new.tar.gz`，重复执行不会残留旧文件。

#### 7.2.4 推送新的 qke-installer 文件包到私有对象存储

```bash
rclone copyto \
  installer-work/staging/qke-installer-v3.4.0-new.tar.gz \
  qingstor:qkeplus/qke-installer-v3.4.0.tar.gz
```

> 推送后，私有对象存储中的 `qke-installer-v3.4.0.tar.gz` 即更新为新包；
> 原始备份（如 `.20260923`）保持不变。
>
> 文件打包仅支持轻量处理（tar 追加），详细操作见根目录
> 《更新qke-installer-v3.4.0文件包操作文档.md》。

## 八、镜像离线保存与推送方法

升级 k8s 到 v1.33.4 时，节点需要从**私有 OCI 注册服务**（默认
`registry.qingcloud.com/kubesphere/`）拉取控制面镜像（`kube-apiserver`、
`kube-controller-manager`、`kube-scheduler`、`kube-proxy`）。由于升级是
**逐 minor 版本**进行的，涉及 **v1.29.15、v1.32.8、v1.33.4** 三个版本
（共 12 个镜像），而非仅 v1.33.4。按以下方式处理。

> **术语**：本文使用"**保存**"（联网机器保存镜像）与"**推送**"（离线环境推送
> 镜像到私有 OCI 注册服务）两个明确动作，全程使用 **crane**，与 docker 无关。
>
> 以下命令均在**项目根目录**执行（`cd <项目根目录>`），脚本与工具使用相对路径。

### 8.1 互联网侧操作（保存镜像）

在联网机器用 crane 保存全部平台 OCI 布局 tar.gz（每个版本执行一次），
保留完整 multi-arch manifest list。

```bash
bash scripts/save-images.sh v1.29.15
bash scripts/save-images.sh v1.32.8
bash scripts/save-images.sh v1.33.4
```

### 8.2 离线环境操作（推送镜像）

将 `offline-images/` 拷贝到离线环境后，用 crane 推送全部平台到私有 OCI 注册服务
（每个版本执行一次）。

```bash
bash scripts/load-push-images.sh v1.33.4 offline-images/ '<用户名>' '<密码>'
```

> 详细说明见根目录《镜像离线保存与推送操作文档.md》。

## 九、常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `crane push` 报 `unauthorized: action: push` | 账号对私有 OCI 注册服务的项目仅有 pull 权限 | 在 Harbor 控制台将账号角色改为 Developer/Maintainer/ProjectAdmin |
| `crane auth login` 报 `unauthorized` | Harbor token 端点要求 scope | 忽略，直接 push |
| 拉取上游镜像/文件超时 | 网络无法访问 `registry.k8s.io` / `dl.k8s.io` | 使用代理，或改用国内镜像源后重新保存/推送 |
| 使用 kk 升级 k8s 时仍尝试联网下载依赖组件 | `qke-installer` 文件包中缺少依赖组件 | 下载缺失组件文件并重新制作 `qke-installer` 文件包（见第七节） |
| 使用 kk 升级 k8s 时 pod 无法拉取镜像 | 私有 OCI 注册服务中缺少镜像 | 在互联网环境保存离线镜像，拷贝到离线环境后推送到私有 OCI 注册服务（见第八节） |
