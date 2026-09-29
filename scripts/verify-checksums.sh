#!/usr/bin/env bash
# =============================================================================
# qke-installer 所需文件 SHA256 校验脚本
# -----------------------------------------------------------------------------
# 校验对象：qke-installer/kubekey/ 下的 KubeKey 依赖二进制
# 校验值来源：KubeKey v3.1.12 源码 version/components.json
# 用法：bash scripts/verify-checksums.sh [基础目录]
#   基础目录默认 = <项目根>/installer-work/downloads/qke-installer/kubekey
#   可传入其他目录（如下载脚本生成的待添加目录）进行校验
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${1:-${SCRIPT_DIR}/../installer-work/downloads/qke-installer/kubekey}"

declare -A EXPECT=(
  ["etcd/v3.5.24/amd64/etcd-v3.5.24-linux-amd64.tar.gz"]="042497e2ddcee06f22e5d486d81f58affa26b53ee423e2a6aaca3d3ea98c8191"
  ["kube/v1.29.15/amd64/kubeadm"]="d0744fbaa1e67fc65c4a3409f083e01a4ede58181c759b2feeb08b1ef10d6201"
  ["kube/v1.29.15/amd64/kubelet"]="cd0228a5820f98bbb6371344e5d6645f6486d767c30f927a1d0ec8d17eca4da5"
  ["kube/v1.29.15/amd64/kubectl"]="3473e14c7b024a6e5403c6401b273b3faff8e5b1fed022d633815eb3168e4516"
  ["kube/v1.32.8/amd64/kubeadm"]="da4cc996800db14f82fce8813caa55be318e52ef69d82e50e728ef4cfa18b69f"
  ["kube/v1.32.8/amd64/kubelet"]="7dfca4da9cdf592c0f70800e09fb42553765bc0951cade3d6e0c571daf3f23ee"
  ["kube/v1.32.8/amd64/kubectl"]="0fc709a8262be523293a18965771fedfba7466eda7ab4337feaa5c028aa46b1b"
  ["kube/v1.33.4/amd64/kubeadm"]="a109ebcb68e52d3dd605d92f92460c884dcc8b68aebe442404af19b6d9d778ec"
  ["kube/v1.33.4/amd64/kubelet"]="109bd2607b054a477ede31c55ae814eae8e75543126dc4cea40b04424d843489"
  ["kube/v1.33.4/amd64/kubectl"]="c2ba72c115d524b72aaee9aab8df8b876e1596889d2f3f27d68405262ce86ca1"
  ["cni/v3.27.4/amd64/calicoctl"]="84f2bd29ef7b06e85a2caf0b6c6e0d3da5ab5264d46b360e6baaf49bbc3b957d"
  ["helm/v3.18.5/amd64/helm"]="0f4167894a59151cc45564642ca1c7d22b251f46055cc96cf2b3f1fda8c22b97"
)

rc=0
for f in "${!EXPECT[@]}"; do
  p="${BASE_DIR}/${f}"
  if [[ ! -f "$p" ]]; then
    echo "MISSING  $f"
    rc=1
    continue
  fi
  got=$(sha256sum "$p" | awk '{print $1}')
  if [[ "$got" == "${EXPECT[$f]}" ]]; then
    echo "OK       $f"
  else
    echo "MISMATCH $f"
    echo "  expect: ${EXPECT[$f]}"
    echo "  got:    $got"
    rc=1
  fi
done
echo "----------------------------------------"
if [[ $rc -eq 0 ]]; then
  echo "全部文件校验通过"
else
  echo "存在缺失或校验失败的文件"
fi
exit $rc
