#!/usr/bin/env bash
# =============================================================================
# 镜像推送脚本（multi-arch）：在离线环境（可访问内部私有仓库）机器上推送全部平台
# -----------------------------------------------------------------------------
# 用途：将 save-images.sh 保存的 OCI 布局 tar.gz 拷贝到离线环境后，用 crane
#       推送到 registry.qingcloud.com/kubesphere/（保留 multi-arch manifest
#       list，全部平台），供 QKE 节点从仓库拉取。
#
# 依赖：crane（全局安装，如 /usr/local/bin/crane）
#
# 用法：
#   bash scripts/load-push-images.sh <版本> [tar目录] [用户名] [密码]
#   版本：v1.29.15 / v1.32.8 / v1.33.4
#   tar 目录默认：offline-images/
#   若提供用户名/密码则先 crane auth login（login 报 unauthorized 可忽略）
#
# 说明：
#   - tar.gz 为 OCI 布局（crane pull --platform all --format oci 保存）
#   - 账号需对 kubesphere 项目具备 push 权限
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ $# -lt 1 ]]; then
    echo "用法: bash $0 <版本> [tar目录] [用户名] [密码]" >&2
    exit 1
fi
VERSION="$1"
TAR_DIR="${2:-${PROJECT_ROOT}/offline-images}"
USERNAME="${3:-}"
PASSWORD="${4:-}"

REGISTRY="registry.qingcloud.com"
PROJECT="kubesphere"
COMPONENTS=(kube-apiserver kube-controller-manager kube-scheduler kube-proxy)

if ! command -v crane >/dev/null 2>&1; then
    echo "[ERROR] 未找到 crane，请先全局安装（如 /usr/local/bin/crane）" >&2
    exit 1
fi

if [[ -n "${USERNAME}" && -n "${PASSWORD}" ]]; then
    echo "==> 登录 ${REGISTRY}（login 报 unauthorized 可忽略）"
    crane auth login "${REGISTRY}" -u "${USERNAME}" -p "${PASSWORD}" || true
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

for comp in "${COMPONENTS[@]}"; do
    TAR_GZ="${TAR_DIR}/${comp}-${VERSION}.tar.gz"
    TARGET="${REGISTRY}/${PROJECT}/${comp}:${VERSION}"
    OCI_DIR="${WORK_DIR}/${comp}-${VERSION}-oci"

    if [[ ! -f "${TAR_GZ}" ]]; then
        echo "[ERROR] 未找到 tar.gz 包: ${TAR_GZ}" >&2
        exit 1
    fi

    echo "==> 解包 ${TAR_GZ}"
    mkdir -p "${OCI_DIR}"
    tar -xzf "${TAR_GZ}" -C "${OCI_DIR}"

    echo "==> 推送全部平台 ${TARGET}"
    crane push "${OCI_DIR}" "${TARGET}"
done

echo "==> 完成。校验：crane manifest ${REGISTRY}/${PROJECT}/kube-apiserver:${VERSION}"
