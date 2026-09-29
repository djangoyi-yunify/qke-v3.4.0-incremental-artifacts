#!/usr/bin/env bash
# =============================================================================
# 下载脚本：下载 qke-installer 需要追加的文件（联网机器执行）
# -----------------------------------------------------------------------------
# 用途：下载 kk 3.1.12、etcd 3.5.24、calicoctl 3.27.4、kube 二进制
#       （v1.29.15 / v1.32.8 / v1.33.4）、helm v3.18.5，校验 SHA256 后放入
#       待添加目录（路径与包内一致，带 qke-installer/ 前缀），供
#       append-to-installer.sh 使用。
#
# 用法：
#   bash scripts/download-installer-files.sh [输出目录]
#   默认输出目录 = <项目根>/installer-work/downloads
#
# 说明：
#   - 需在联网机器执行
#   - 校验和来源：kk 3.1.12 官方 version/components.json
#   - 输出目录结构：
#       <输出目录>/qke-installer/kk
#       <输出目录>/qke-installer/kubekey/{etcd,cni,kube,helm}/...
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${1:-${PROJECT_ROOT}/installer-work/downloads}"

KK_VERSION="3.1.12"
ETCD_VERSION="3.5.24"
CALICO_VERSION="3.27.4"
KUBE_VERSIONS=("1.29.15" "1.32.8" "1.33.4")
HELM_VERSION="3.18.5"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${OUT_DIR}/qke-installer/kubekey"

echo "==> 1/5 下载 kubekey ${KK_VERSION}"
curl -fSL -o "${TMP_DIR}/kubekey.tar.gz" \
  "https://github.com/kubesphere/kubekey/releases/download/v${KK_VERSION}/kubekey-v${KK_VERSION}-linux-amd64.tar.gz"
tar -xzf "${TMP_DIR}/kubekey.tar.gz" -C "${TMP_DIR}"
cp -f "${TMP_DIR}/kk" "${OUT_DIR}/qke-installer/kk"
chmod 755 "${OUT_DIR}/qke-installer/kk"
echo "    kk 版本: $("${OUT_DIR}/qke-installer/kk" version | grep -o 'GitVersion:"[^"]*"' || echo '未知')"

echo "==> 2/5 下载 etcd ${ETCD_VERSION}"
curl -fSL -o "${TMP_DIR}/etcd.tar.gz" \
  "https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
mkdir -p "${OUT_DIR}/qke-installer/kubekey/etcd/v${ETCD_VERSION}/amd64"
cp -f "${TMP_DIR}/etcd.tar.gz" \
  "${OUT_DIR}/qke-installer/kubekey/etcd/v${ETCD_VERSION}/amd64/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"

echo "==> 3/5 下载 calicoctl ${CALICO_VERSION}"
mkdir -p "${OUT_DIR}/qke-installer/kubekey/cni/v${CALICO_VERSION}/amd64"
curl -fSL -o "${OUT_DIR}/qke-installer/kubekey/cni/v${CALICO_VERSION}/amd64/calicoctl" \
  "https://github.com/projectcalico/calico/releases/download/v${CALICO_VERSION}/calicoctl-linux-amd64"
chmod 755 "${OUT_DIR}/qke-installer/kubekey/cni/v${CALICO_VERSION}/amd64/calicoctl"

echo "==> 4/5 下载 kube 二进制（kubeadm/kubelet/kubectl）"
for v in "${KUBE_VERSIONS[@]}"; do
  mkdir -p "${OUT_DIR}/qke-installer/kubekey/kube/v${v}/amd64"
  for bin in kubeadm kubelet kubectl; do
    curl -fSL -o "${OUT_DIR}/qke-installer/kubekey/kube/v${v}/amd64/${bin}" \
      "https://dl.k8s.io/release/v${v}/bin/linux/amd64/${bin}"
    chmod 755 "${OUT_DIR}/qke-installer/kubekey/kube/v${v}/amd64/${bin}"
  done
  echo "    v${v} 完成"
done

echo "==> 5/5 下载 helm ${HELM_VERSION}"
curl -fSL -o "${TMP_DIR}/helm.tar.gz" \
  "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz"
tar -xzf "${TMP_DIR}/helm.tar.gz" -C "${TMP_DIR}"
mkdir -p "${OUT_DIR}/qke-installer/kubekey/helm/v${HELM_VERSION}/amd64"
cp -f "${TMP_DIR}/linux-amd64/helm" \
  "${OUT_DIR}/qke-installer/kubekey/helm/v${HELM_VERSION}/amd64/helm"
chmod 755 "${OUT_DIR}/qke-installer/kubekey/helm/v${HELM_VERSION}/amd64/helm"

echo "==> 校验 SHA256（kk 3.1.12 components.json）"
bash "${SCRIPT_DIR}/verify-checksums.sh" "${OUT_DIR}/qke-installer/kubekey"

echo "==> 完成。待添加目录: ${OUT_DIR}"
find "${OUT_DIR}" -type f | sort
