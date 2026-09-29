# QKE Installer 文件包更新操作文档

> **目的**：让用户参照本文档，在离线环境将 `qke-installer-v3.4.0.tar.gz` 更新为
> 支持 k8s 1.33.4 的最终版本（kk 3.1.12 + kubekey 依赖 + helm v3.18.5）。
> 本文档按**最终状态**撰写，描述完整更新流程：
> **互联网侧下载文件 → 离线环境侧（备份 → 校验 → 制作 → 推送）**。

---

## 一、背景与最终状态

QKE 3.4.0 内置的 `qke-installer-v3.4.0.tar.gz` 中 kk 为 **3.1.7**，最高仅支持
k8s 1.31.2，无法升级到 1.33.4。需将 kk 升级到 **3.1.12**，并补齐 kk 3.1.12
创建/升级集群时**自动下载**的依赖二进制，实现离线安装/升级。

### 最终包内容

```
qke-installer/
├── kk                                          # kubekey 3.1.12
└── kubekey/                                    # KubeKey 依赖二进制
    ├── etcd/v3.5.24/amd64/etcd-v3.5.24-linux-amd64.tar.gz
    ├── cni/v3.27.4/amd64/calicoctl
    ├── kube/
    │   ├── v1.29.15/amd64/{kubeadm,kubelet,kubectl}
    │   ├── v1.32.8/amd64/{kubeadm,kubelet,kubectl}
    │   └── v1.33.4/amd64/{kubeadm,kubelet,kubectl}
    └── helm/v3.18.5/amd64/helm                  # kk 创建集群时自动下载
```

- 最终包大小：以实际打包结果为准
- 包内路径均带 `qke-installer/` 顶层前缀，打包方式为 gzip

## 二、前置条件与工具

| 工具 | 说明 |
| --- | --- |
| 联网机器 | 下载 kk 3.1.12、helm v3.18.5、k8s 二进制（`registry.k8s.io` / `get.helm.sh` / GitHub） |
| rclone v1.75.1 | 上传/下载私有对象存储对象；配置在默认位置 `~/.config/rclone/rclone.conf`（远程名 `qingstor`，bucket `qkeplus`，zone `pek3b`） |
| 文件包地址 | 私有对象存储中的 `qke-installer-v3.4.0.tar.gz`（默认 `https://qkeplus.pek3b.qingstor.com/qke-installer-v3.4.0.tar.gz`） |

## 三、更新步骤

> 以下命令均在**项目根目录**执行（`cd <项目根目录>`），脚本与工具使用相对路径。

操作分为**互联网侧操作**与**离线环境侧操作**。

### 1. 互联网侧操作：下载需要追加的文件

在联网机器下载以下文件（校验和清单见附录，权威来源为 kk 3.1.12 官方
`version/components.json`，脚本内部已逐一校验 SHA256）：

| 文件 | 存放路径（包内） | 来源 |
| --- | --- | --- |
| kk 3.1.12 | `qke-installer/kk` | GitHub kubekey v3.1.12 release |
| etcd 3.5.24 | `qke-installer/kubekey/etcd/v3.5.24/amd64/` | `get.etcd.io` |
| calicoctl 3.27.4 | `qke-installer/kubekey/cni/v3.27.4/amd64/` | GitHub projectcalico |
| kube v1.29.15 / v1.32.8 / v1.33.4 | `qke-installer/kubekey/kube/<版本>/amd64/` | `dl.k8s.io` |
| helm v3.18.5 | `qke-installer/kubekey/helm/v3.18.5/amd64/` | `get.helm.sh` |

```bash
bash scripts/download-installer-files.sh
```

> 本资源包 `installer-work/downloads/` 目录已包含上述全部最终文件，可直接使用。

### 2. 离线环境侧操作

#### 2.1 备份私有对象存储中的 qke-installer

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

> 原始备份对象（如 `qke-installer-v3.4.0.tar.gz.20260923`）**必须保持不变**。

#### 2.2 校验下载的文件

```bash
bash scripts/verify-checksums.sh
```

#### 2.3 制作新的 qke-installer 文件包

文件打包仅支持**轻量处理（tar 追加）**：从备份拷贝基础包 → tar 追加并压缩。

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

> 说明：gzip 为流式格式无法直接增量追加，仍需解压+重压缩；但省去了最耗时的
> tar 逐文件解压/重打包。追加的文件若与包内已有文件同名，解压时以最后出现的
> 为准（可覆盖替换）。

#### 2.4 推送新的 qke-installer 文件包到私有对象存储

```bash
rclone copyto \
  installer-work/staging/qke-installer-v3.4.0-new.tar.gz \
  qingstor:qkeplus/qke-installer-v3.4.0.tar.gz
```

### 3. 验证

```bash
# 校验依赖 SHA256（kk 3.1.12 官方 components.json）
bash scripts/verify-checksums.sh

# 确认私有对象存储中的对象与备份
rclone lsl qingstor:qkeplus | grep qke-installer-v3.4.0
# 期望：
#   qke-installer-v3.4.0.tar.gz          新包（大小与本地一致）
#   qke-installer-v3.4.0.tar.gz.20260923 原始备份（保持不变）
```

## 四、附录

### 4.1 校验和清单（SHA256）

| 文件 | SHA256 |
| --- | --- |
| kk 3.1.12 | GitCommit `17c1df861a1e7f2f21af4f0ef4e4d34907ddda7b` |
| etcd/v3.5.24/amd64/etcd-v3.5.24-linux-amd64.tar.gz | `042497e2ddcee06f22e5d486d81f58affa26b53ee423e2a6aaca3d3ea98c8191` |
| cni/v3.27.4/amd64/calicoctl | `84f2bd29ef7b06e85a2caf0b6c6e0d3da5ab5264d46b360e6baaf49bbc3b957d` |
| kube/v1.29.15/amd64/kubeadm | `d0744fbaa1e67fc65c4a3409f083e01a4ede58181c759b2feeb08b1ef10d6201` |
| kube/v1.29.15/amd64/kubelet | `cd0228a5820f98bbb6371344e5d6645f6486d767c30f927a1d0ec8d17eca4da5` |
| kube/v1.29.15/amd64/kubectl | `3473e14c7b024a6e5403c6401b273b3faff8e5b1fed022d633815eb3168e4516` |
| kube/v1.32.8/amd64/kubeadm | `da4cc996800db14f82fce8813caa55be318e52ef69d82e50e728ef4cfa18b69f` |
| kube/v1.32.8/amd64/kubelet | `7dfca4da9cdf592c0f70800e09fb42553765bc0951cade3d6e0c571daf3f23ee` |
| kube/v1.32.8/amd64/kubectl | `0fc709a8262be523293a18965771fedfba7466eda7ab4337feaa5c028aa46b1b` |
| kube/v1.33.4/amd64/kubeadm | `a109ebcb68e52d3dd605d92f92460c884dcc8b68aebe442404af19b6d9d778ec` |
| kube/v1.33.4/amd64/kubelet | `109bd2607b054a477ede31c55ae814eae8e75543126dc4cea40b04424d843489` |
| kube/v1.33.4/amd64/kubectl | `c2ba72c115d524b72aaee9aab8df8b876e1596889d2f3f27d68405262ce86ca1` |
| helm/v3.18.5/amd64/helm | `0f4167894a59151cc45564642ca1c7d22b251f46055cc96cf2b3f1fda8c22b97` |

> 权威校验和来源：kk 3.1.12 官方 `version/components.json`；可用
> `scripts/verify-checksums.sh` 自动校验。

### 4.2 相关脚本

| 脚本 | 用途 |
| --- | --- |
| `scripts/download-installer-files.sh` | 联网机器：下载 qke-installer 待追加文件并校验 SHA256 |
| `scripts/append-to-installer.sh` | 轻量打包：向 tar.gz 追加文件（gunzip → tar -rf → gzip） |
| `scripts/verify-checksums.sh` | 校验 kubekey 依赖 SHA256（含 helm v3.18.5） |

### 4.3 常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 上传后私有对象存储中的对象大小与本地不一致 | 上传未完成 | 等待 rclone 完成后再 `lsl` 确认 |
| 备份对象（如 `.20260923`）被覆盖 | 误用 `copyto` 覆盖 | 原始备份只做一次，用 `moveto` 重命名 |
| 操作前未保存原始包到 `origin/` | 忘记本地备份 | 每次操作前执行 `rclone copy qingstor:qkeplus/qke-installer-v3.4.0.tar.gz installer-work/origin/` |
| kk 升级时仍尝试联网下载 | `kubekey/` 目录未放到 kk 的 workDir | 将 `qke-installer/kubekey/` 放到 kk 二进制所在目录下（`<kk目录>/kubekey`） |
