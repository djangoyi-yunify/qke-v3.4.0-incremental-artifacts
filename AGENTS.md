# AGENTS.md

AI agent 工作指南。开始任何任务前，先读本文件与 `CONTEXT.md`。

## 项目定位

QKE 3.4.0 离线升级 Kubernetes 到 v1.33.4 的资源准备：提供新的
`qke-installer-v3.4.0.tar.gz` 文件包（kk 3.1.12 + 依赖 + helm v3.18.5）、
crane 镜像保存/推送方法与离线镜像文件。

## 布局约定

- 文档放**项目根目录**；脚本放 `scripts/`（bash）
- `offline-images/`、`installer-work/` 是二进制目录，`.gitignore` 已排除，不入库
- 命令一律从**项目根目录**执行

## 工作约定

- **crane 工作流**：镜像保存 → 拷贝 → 推送，全程 crane（无 docker）
- **通用化**：操作文档面向任意离线环境，用"默认 xxx"表述；青云公有云环境的具体
  状态（字节数、摘要、账号）只写入《青云公有云环境调整记录.md》
- **术语**：私有对象存储 / 私有 OCI 注册服务 / project（默认 kubesphere），见 CONTEXT.md

## 验证

- 脚本：`bash -n scripts/*.sh`
- 依赖：`bash scripts/verify-checksums.sh`（须全部通过）
- 文档：章节引用正确、术语一致、无青云具体值残留（操作记录除外）

## Git

- 二进制不入库；提交前 `git status` 确认无二进制被暂存
- 提交信息用中文

## 文档索引

- 综合：`README.md`
- 文件包更新：《更新qke-installer-v3.4.0文件包操作文档.md》
- 镜像保存/推送：《镜像离线保存与推送操作文档.md》
- 青云环境现状：《青云公有云环境调整记录.md》
