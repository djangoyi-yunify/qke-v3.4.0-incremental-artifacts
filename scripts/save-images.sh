#!/usr/bin/env bash
# =============================================================================
# 镜像保存脚本（multi-arch）：在联网机器上保存上游控制面镜像（全部平台）
# -----------------------------------------------------------------------------
# 用途：QKE 离线升级 k8s 到 v1.33.4 时，在可访问外网的机器上，用 crane 将
#       registry.k8s.io 的控制面镜像按 multi-arch（全部平台）保存为 OCI 布局
#       tar.gz，供拷贝到离线环境后推送到内部私有仓库。
#
# 依赖：crane（全局安装，如 /usr/local/bin/crane）
#
# 用法：
#   bash scripts/save-images.sh <版本> [输出目录]
#   版本：v1.29.15 / v1.32.8 / v1.33.4
#   输出目录默认：offline-images/
#   输出：<输出目录>/<组件>-<版本>.tar.gz（OCI 布局，含全部平台）
#
# 说明：
#   - 每个版本保存 4 个控制面镜像（kube-apiserver / kube-controller-manager /
#     kube-scheduler / kube-proxy）
#   - 使用 crane pull --platform all --format oci 保存完整 manifest list
#     （amd64/arm64/ppc64le/s390x 等全部平台）
#   - 对应推送脚本：scripts/load-push-images.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ $# -lt 1 ]]; then
    echo "用法: bash $0 <版本> [输出目录，默认 offline-images/]" >&2
    exit 1
fi
VERSION="$1"
OUT_DIR="${2:-${PROJECT_ROOT}/offline-images}"

UPSTREAM_REGISTRY="registry.k8s.io"
COMPONENTS=(kube-apiserver kube-controller-manager kube-scheduler kube-proxy)

if ! command -v crane >/dev/null 2>&1; then
    echo "[ERROR] 未找到 crane，请先全局安装（如 /usr/local/bin/crane）" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"

for comp in "${COMPONENTS[@]}"; do
    UPSTREAM="${UPSTREAM_REGISTRY}/${comp}:${VERSION}"
    OCI_DIR="${OUT_DIR}/${comp}-${VERSION}-oci"
    TAR_GZ="${OUT_DIR}/${comp}-${VERSION}.tar.gz"

    echo "==> 保存全部平台 ${UPSTREAM}"
    crane pull --platform all --format oci "${UPSTREAM}" "${OCI_DIR}"

    echo "==> 打包 ${TAR_GZ}（OCI 布局，全部平台）"
    tar -czf "${TAR_GZ}" -C "${OCI_DIR}" .
    rm -rf "${OCI_DIR}"
done

echo "==> 完成。已保存到 ${OUT_DIR}:"
ls -lh "${OUT_DIR}"/kube-*-"${VERSION}".tar.gz
