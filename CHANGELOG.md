# 变更记录

本项目变更记录，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## 2026-09-29

### 新增

- 项目初始化：QKE 3.4.0 离线升级 k8s 到 v1.33.4 资源准备
  - `README.md` 综合文档
  - 《更新qke-installer-v3.4.0文件包操作文档.md》
  - 《镜像离线保存与推送操作文档.md》
  - 《青云公有云环境调整记录.md》
  - `scripts/`：save-images / load-push-images / download-installer-files / verify-checksums / append-to-installer
  - `.gitignore`（排除二进制文件）
- `AGENTS.md`、`CONTEXT.md`（AI agent 工作指南与领域模型）

### 变更

- 增强脚本对目录缺失的健壮性（`append-to-installer.sh`、`load-push-images.sh`）
- README 与更新文档 7.2.1/7.2.3 增加 `mkdir -p` 创建目录命令
