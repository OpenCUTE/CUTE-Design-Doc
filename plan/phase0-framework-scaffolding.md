# Phase 0 — 框架搭建

## 方法论

本阶段采用 **脚手架优先（Scaffolding First）** 方法论：

- **项目脚手架（Project Scaffolding）**：在编写任何实际文档内容之前，先建立完整的目录骨架和构建基础设施，确保后续所有文档工作有一个稳定、可验证的底座。
- **约定优于配置（Convention over Configuration）**：沿袭 MkDocs + mkdocs-material 的成熟约定，仅对 CUTE 特有需求做定制，减少初期决策成本。
- **基础设施即代码（Infrastructure as Code）**：所有构建、检查、部署逻辑均通过 Makefile、CI 配置和配置文件声明式管理，可复现、可版本化。

---

## 整体框架进度

```
Phase 0 ─── [当前阶段] 框架搭建
Phase 1 ─── 核心文档（overview/ + hardware/）
Phase 2 ─── 指令集与数据类型
Phase 3 ─── 软件与测试
Phase 4 ─── 自动化与发布
```

**当前进度：0%** — 尚未创建任何脚手架文件，所有基础设施待搭建。

完成后将达到：目录骨架就绪、本地预览可用、lint 检查可运行、CI 流水线已配置（但尚无实际文档内容）。

---

## 实施细节

### 步骤 0.1 — 初始化项目基础文件

**方法论：约定优于配置**

创建以下根目录文件：

| 文件 | 说明 | 要点 |
|---|---|---|
| `mkdocs.yml` | MkDocs 主配置 | 语言设为 zh；启用 navigation.tabs、navigation.indexes、search.suggest、content.mermaid、content.code.copy |
| `Makefile` | 统一构建入口 | 提供 `serve`、`build`、`pdf`、`lint`、`clean` 五个目标 |
| `.markdownlint.yml` | Markdown 格式规范 | 继承香山的规则集，调整为允许中文标点 |
| `.gitignore` | 忽略构建产物 | 忽略 `site/`、`build/`、`__pycache__/` |
| `LICENSE` | 许可证 | CC BY 4.0（与香山一致） |

**mkdocs.yml 关键配置项：**

```yaml
site_name: CUTE Design Document
site_description: CPU 集成张量加速器设计文档
theme:
  name: material
  language: zh
  features:
    - navigation.tabs
    - navigation.indexes
    - navigation.tracking
    - search.suggest
    - search.highlight
    - content.mermaid
    - content.code.copy
  palette:
    - scheme: default
      toggle:
        icon: material/brightness-7
        name: 切换暗色模式
    - scheme: slate
      toggle:
        icon: material/brightness-4
        name: 切换亮色模式

plugins:
  - search
  - mermaid2

markdown_extensions:
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:mermaid2.fence_mermaid
  - pymdownx.arithmatex:
      generic: true
  - tables
  - footnotes
  - attr_list
  - md_in_html
  - toc:
      permalink: true

nav:
  - 首页: index.md
  - 项目概述: overview/
  - 硬件设计: hardware/
  - 指令集: instruction-set/
  - 数据类型: datatypes/
  - 软件与测试: software/
  - 附录: appendix/
```

**Makefile 模板：**

```makefile
.PHONY: serve build pdf lint clean

serve:
	mkdocs serve

build:
	mkdocs build

pdf:
	@mkdir -p build
	pandoc docs/index.md \
	  docs/overview/*.md \
	  docs/hardware/**/*.md \
	  docs/instruction-set/*.md \
	  docs/datatypes/*.md \
	  docs/software/*.md \
	  docs/appendix/*.md \
	  --pdf-engine=xelatex \
	  -V mainfont="Noto Sans CJK SC" \
	  -V monofont="JetBrains Mono" \
	  -V geometry:margin=1in \
	  --filter pandoc-crossref \
	  -o build/cute-design-doc.pdf

lint:
	markdownlint-cli2 "docs/**/*.md"

clean:
	rm -rf site/ build/
```

---

### 步骤 0.2 — 创建目录骨架

**方法论：脚手架优先**

按照 `cute-design-doc-plan.md` 第三章 3.2 节定义的目录结构，创建所有目录和占位 `index.md` 文件。

**目标目录树：**

```
docs/
├── index.md                        # 首页（占位）
├── overview/
│   └── index.md                    # 概述导航（占位）
├── hardware/
│   ├── index.md                    # 硬件设计导航（占位）
│   ├── compute-engine/
│   │   └── index.md
│   ├── memory-system/
│   │   └── index.md
│   ├── control-logic/
│   │   └── index.md
│   └── integration/
│       └── index.md
├── instruction-set/
│   └── index.md
├── datatypes/
│   └── index.md
├── software/
│   └── index.md
├── appendix/
│   └── index.md
└── shared/
    └── figures/
        ├── architecture/
        ├── microarch/
        └── timing/
```

**每个占位 index.md 的最小内容模板：**

```markdown
# {模块名称}

> 本文档为占位页面，内容将在后续阶段填充。

## 导航

- [返回上级](../index.md)
```

**实施方式：** 用 shell 脚本或手动创建所有目录和占位文件，确保 `mkdocs serve` 可以无报错启动。

---

### 步骤 0.3 — 配置质量保证工具

**方法论：基础设施即代码**

#### 0.3.1 markdownlint 配置

创建 `.markdownlint.yml`：

```yaml
# 继承默认规则，做以下调整
MD009: false      # 允许行尾空格（中文排版习惯）
MD013: false      # 不限制行长度（中文段落不适合硬换行）
MD033: false      # 允许内嵌 HTML（WaveDrom/Mermaid 需要）
MD041: false      # 允许非标题开头（index.md 可能以导航开头）
MD024: false      # 允许重复标题名（不同层级的 index.md 会重复 "导航"）
```

#### 0.3.2 lint 工具容器化（可选）

创建 `tools/lint/Dockerfile`：

```dockerfile
FROM node:20-slim
RUN npm install -g markdownlint-cli2
WORKDIR /docs
ENTRYPOINT ["markdownlint-cli2"]
```

创建 `tools/lint/run-lint.sh`：

```bash
#!/bin/bash
set -e
docker build -t md-lint tools/lint/
docker run --rm -v "$(pwd):/docs" md-lint "docs/**/*.md"
```

---

### 步骤 0.4 — 配置 CI/CD 流水线

**方法论：基础设施即代码**

#### 0.4.1 GitHub Actions — lint + build 检查

创建 `.github/workflows/ci.yml`：

```yaml
name: CI
on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.13'
      - run: pip install mkdocs-material mkdocs-mermaid2-plugin
      - run: pip install markdownlint-cli2 || npm install -g markdownlint-cli2
      - run: markdownlint-cli2 "docs/**/*.md"
      - run: mkdocs build --strict

  deploy:
    needs: lint
    if: github.ref == 'refs/heads/master'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.13'
      - run: pip install mkdocs-material mkdocs-mermaid2-plugin
      - run: mkdocs build
      - uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./site
```

#### 0.4.2 Issue 模板

创建 `.github/ISSUE_TEMPLATE/config.yml`：

```yaml
blank_issues_enabled: false
contact_links:
  - name: 文档问题
    url: https://github.com/{org}/CUTE/issues/new?template=document-bug.yml
    about: 报告文档中的错误或改进建议
```

创建 `.github/ISSUE_TEMPLATE/document-bug.yml`：

```yaml
name: 文档问题
description: 报告文档中的错误或不准确之处
labels: ["documentation"]
body:
  - type: input
    id: location
    attributes:
      label: 文档位置
      description: 哪个页面或文件有问题？
    validations:
      required: true
  - type: textarea
    id: description
    attributes:
      label: 问题描述
    validations:
      required: true
  - type: textarea
    id: suggestion
    attributes:
      label: 建议修改
```

---

### 步骤 0.5 — 验证脚手架可用性

**方法论：脚手架优先 — 脚手架必须可运行**

验收清单：

- [ ] `mkdocs serve` 可正常启动，本地可预览所有占位页面
- [ ] `make lint` 可运行，无报错（占位页面格式正确）
- [ ] `make build` 可成功生成 `site/` 目录
- [ ] GitHub Actions CI 可通过（在首次 push 后验证）
- [ ] 目录结构与 plan 中 3.2 节完全一致

---

## 产出物

| 产出物 | 路径 |
|---|---|
| MkDocs 配置 | `mkdocs.yml` |
| 构建脚本 | `Makefile` |
| Markdown 规范 | `.markdownlint.yml` |
| CI 流水线 | `.github/workflows/ci.yml` |
| Issue 模板 | `.github/ISSUE_TEMPLATE/` |
| 文档目录骨架 | `docs/` 下所有目录和占位文件 |
| 全局图片目录 | `docs/shared/figures/` |
| Git 忽略配置 | `.gitignore` |
| 许可证 | `LICENSE` |
| Lint 工具 | `tools/lint/` |

---

## 依赖与风险

| 项目 | 说明 |
|---|---|
| **Python 3.11+** | MkDocs 运行时依赖 |
| **Pandoc + XeLaTeX** | PDF 生成依赖（Phase 4 才会实际使用，Phase 0 可暂不安装） |
| **Node.js** | markdownlint-cli2 运行时（或使用 Docker 容器化方案） |
| **风险** | mkdocs-mermaid2-plugin 与 mkdocs-material 的 Mermaid 支持可能有冲突，需要测试确定使用哪种方式 |
