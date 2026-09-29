#!/usr/bin/env bash
# =============================================================================
# 轻量更新脚本：向 qke-installer-v3.4.0.tar.gz 追加文件（tar 追加方式）
# -----------------------------------------------------------------------------
# 用途：只向现有 tar.gz 追加文件，不解压全部内容重打包，速度快。
#       适用于新增依赖二进制（如 helm v3.18.5）或替换 kk 等。
#
# 用法：
#   bash scripts/append-to-installer.sh <基础tar.gz> <待添加目录> [输出tar.gz]
#   基础tar.gz  ：当前 qke-installer-v3.4.0.tar.gz
#   待添加目录  ：包含待添加文件的目录，路径与包内一致（带 qke-installer/ 前缀）
#   输出tar.gz  ：默认 <基础tar.gz 同目录>/qke-installer-v3.4.0-new.tar.gz
#
# 示例（追加 helm v3.18.5）：
#   mkdir -p staging/qke-installer/kubekey/helm/v3.18.5/amd64
#   cp linux-amd64/helm staging/qke-installer/kubekey/helm/v3.18.5/amd64/helm
#   bash scripts/append-to-installer.sh \
#       qke-installer-v3.4.0.tar.gz staging qke-installer-v3.4.0-new.tar.gz
#
# 说明：
#   - 追加方式：gunzip → tar -rf 追加 → gzip
#   - 追加的文件若与包内已有文件同名，解压时以最后出现的为准（可覆盖替换）
#   - gzip 为流式格式无法直接增量追加，仍需解压+重压缩，但省去 tar 逐文件处理
# =============================================================================
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "用法: bash $0 <基础tar.gz> <待添加目录> [输出tar.gz]" >&2
    exit 1
fi

BASE_TAR_GZ="$1"
ADD_DIR="$2"
OUTPUT="${3:-$(dirname "${BASE_TAR_GZ}")/qke-installer-v3.4.0-new.tar.gz}"

# 先校验输入存在，再转绝对路径（避免目录缺失时 cd 报错信息晦涩）
if [[ ! -f "${BASE_TAR_GZ}" ]]; then
    echo "[ERROR] 未找到基础 tar.gz: ${BASE_TAR_GZ}" >&2
    exit 1
fi
if [[ ! -d "${ADD_DIR}" ]]; then
    echo "[ERROR] 未找到待添加目录: ${ADD_DIR}" >&2
    exit 1
fi

BASE_TAR_GZ="$(cd "$(dirname "${BASE_TAR_GZ}")" && pwd)/$(basename "${BASE_TAR_GZ}")"
ADD_DIR="$(cd "${ADD_DIR}" && pwd)"

# 输出目录不存在则自动创建（installer-work/staging 等可能未随 git 克隆）
OUTPUT_DIR="$(dirname "${OUTPUT}")"
mkdir -p "${OUTPUT_DIR}"
OUTPUT="$(cd "${OUTPUT_DIR}" && pwd)/$(basename "${OUTPUT}")"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "==> 1/4 校验并解压为 tar（流式解压）"
gzip -t "${BASE_TAR_GZ}"
gunzip -c "${BASE_TAR_GZ}" > "${WORK_DIR}/base.tar"

echo "==> 2/4 追加文件（tar -rf）"
while IFS= read -r -d '' f; do
    rel="${f#${ADD_DIR}/}"
    echo "    追加: ${rel}"
    tar -rf "${WORK_DIR}/base.tar" -C "${ADD_DIR}" "${rel}"
done < <(find "${ADD_DIR}" -type f -print0)

echo "==> 3/4 重新压缩为 gzip"
gzip -f "${WORK_DIR}/base.tar"

echo "==> 4/4 输出 -> ${OUTPUT}"
mv "${WORK_DIR}/base.tar.gz" "${OUTPUT}"

echo "==> 完成。输出文件: ${OUTPUT}"
ls -lh "${OUTPUT}"
