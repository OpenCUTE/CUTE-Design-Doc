# 香山设计文档仓库 — 技术栈深度分析

> 基于 `/root/opencute/XiangShan-Design-Doc` 仓库及其 `utils/` 子模块的完整源码分析，提炼其技术栈选型方法论。

---

## 一、技术栈全景

### 1.1 工具链一览

```
写作层    Markdown (.md) + YAML (.yml)
─────────────────────────────────────────
检查层    markdownlint-cli2 + lint-md
─────────────────────────────────────────
构建层    MkDocs (网站)     Pandoc + XeLaTeX (PDF)
          ├ mkdocs-material  ├ pandoc-crossref
          ├ Python 扩展 ×6   ├ Lua 过滤器 ×3
          ├ jieba (中文搜索)  ├ rsvg-convert (SVG→PDF)
          └ Mermaid/MathJax   └ ctexbook (中文排版)
─────────────────────────────────────────
部署层    ReadTheDocs (网站)   GitHub Releases (PDF)
─────────────────────────────────────────
CI/CD     GitHub Actions ×3
          ├ build-pandoc.yml    (自动构建 PDF)
          ├ release.yml         (版本发布)
          └ issue-command.yml   (Issue 管理)
─────────────────────────────────────────
容器化    Docker ×2
          ├ utils/Dockerfile    (Pandoc+LaTeX 构建环境)
          └ tools/lint/Dockerfile (lint 环境)
```

### 1.2 完整依赖图

```
                         ┌─────────────┐
                         │  Markdown   │
                         │  源文件 .md │
                         └──────┬──────┘
                                │
                    ┌───────────┼───────────┐
                    ▼                       ▼
            ┌───────────────┐       ┌───────────────┐
            │    MkDocs     │       │    Pandoc     │
            │  (Web 构建)   │       │  (PDF 构建)   │
            └───────┬───────┘       └───────┬───────┘
                    │                       │
            ┌───────┴───────┐       ┌───────┴───────┐
            │ mkdocs-material│      │ XeLaTeX       │
            │ Python 扩展 ×6 │      │ pandoc-crossref│
            │ custom_theme  │      │ Lua 过滤器 ×3  │
            │ jieba         │      │ ctexbook      │
            │ MathJax       │      │ rsvg-convert  │
            └───────┬───────┘      └───────┬───────┘
                    │                       │
                    ▼                       ▼
            ┌───────────────┐       ┌───────────────┐
            │ ReadTheDocs   │       │ GitHub        │
            │ (在线网站)     │       │ Releases (PDF)│
            └───────────────┘       └───────────────┘
```

---

## 二、Web 构建管线：MkDocs

### 2.1 为什么选 MkDocs

| 对比维度 | MkDocs | Sphinx | Hugo | Docusaurus |
|---|---|---|---|---|
| 写作格式 | Markdown 原生 | reStructuredText 主力 | Markdown 原生 | Markdown + MDX |
| 学习曲线 | 低 | 中（需学 rst） | 中（模板语法） | 中（React 生态） |
| 主题生态 | mkdocs-material 极强 | readthedocs 主题 | 丰富 | 丰富 |
| 中文支持 | jieba 分词、ctex 集成 | 一般 | 一般 | 一般 |
| PDF 导出 | 不内置（配合 Pandoc） | 内置 | 不内置 | 不内置 |
| 多项目协调 | 配置继承 + 子模块 | intersphinx | Hugo Modules | npm 生态 |

香山选 MkDocs 的理由：
1. **Markdown-first**：降低硬件工程师写作门槛，无需学习 rst 或模板语法
2. **mkdocs-material**：功能最完善的文档主题（搜索、导航、暗色、Mermaid）
3. **配置继承**：`INHERIT` 机制天然支持多语言共享配置
4. **Python 生态**：方便写 Markdown 扩展来兼容 Pandoc 语法

### 2.2 配置继承体系

```
mkdocs.yml (入口，1行)
    │
    └── INHERIT: !ENV [MKDOCS_YML_FILE, "mkdocs-zh.yml"]
            │
            ├── mkdocs-zh.yml
            │       │
            │       └── INHERIT: utils/mkdocs-base.yml  ← 共享基础
            │               │
            │               ├── 主题配置
            │               ├── Markdown 扩展（6个）
            │               ├── 搜索插件（jieba 分词）
            │               └── 自定义 CSS/JS
            │               ├── 中文变量: docs/variables-zh.yml
            │               ├── docs_dir: docs/zh
            │               └── nav: (中文导航)
            │
            └── mkdocs-en.yml
                    │
                    └── INHERIT: utils/mkdocs-base.yml  ← 同一基础
                            │
                            ├── 英文变量: docs/variables-en.yml
                            ├── docs_dir: docs/en
                            └── nav: (英文导航)
```

**`mkdocs-base.yml` 的关键配置**（位于 `utils/` 子模块）：

```yaml
theme:
  name: material
  custom_dir: utils/custom_theme
  language: zh
  features:
    - navigation.indexes      # 目录页作为导航节点
    - navigation.top          # 返回顶部按钮
    - navigation.footer       # 页脚导航
    - content.actions         # 编辑此页链接

markdown_extensions:
  - pymdownx.arithmatex      # LaTeX 数学公式
  - xiangshan_docs_utils.crossref        # 交叉引用
  - xiangshan_docs_utils.remove_include  # 移除 Pandoc include 块
  - xiangshan_docs_utils.replace_variables  # 变量替换
  - xiangshan_docs_utils.table_captions    # 表格标题
  - markdown_grid_tables     # Grid 表格语法
  - markdown_captions        # 图片标题

plugins:
  - search:
      lang:
        - zh                  # jieba 中文分词
        - en
```

### 2.3 六个自研 Python Markdown 扩展

位于 `utils/mdx_extensions/`，打包为 `xiangshan_docs_utils`：

#### (1) `replace_variables.py` — 变量替换

**解决问题**：版本号、项目名等需要集中管理。

```yaml
# 配置
markdown_extensions:
  replace_variables:
    yaml_file: docs/variables-zh.yml
```

```yaml
# variables-zh.yml
replace_variables:
  processor_name: "昆明湖 V2R2"
```

```markdown
# {{processor_name}} BPU 模块文档
```

→ 渲染为：`# 昆明湖 V2R2 BPU 模块文档`

#### (2) `crossref.py` — Pandoc 风格交叉引用

**解决问题**：让 `[@fig:xxx]`、`[@tbl:xxx]` 在 MkDocs 网站中也能工作。

```yaml
# 配置
crossref:
  figPrefix: ["图", "图"]
  tblPrefix: ["表", "表"]
  remove_ref_types: ['sec']   # 不渲染章节引用
```

```markdown
![架构图](fig.svg){#fig:arch}

如 [@fig:arch] 所示...  →  渲染为："如 图 arch 所示"（可点击链接）
```

支持的引用类型：`fig`（图）、`tbl`（表）、`eq`（公式）、`lst`（代码）、`sec`（章节）。

#### (3) `remove_include.py` — 移除 Pandoc include 块

**解决问题**：Pandoc 用 ` ```{.include} ` 语法拼接多文件，但 MkDocs 不识别。

````markdown
```{.include}
module1.md
module2.md
```
````

→ 在 MkDocs 渲染时被静默移除（Pandoc 构建时正常展开）。

#### (4) `remove_references.py` — 清理引用标签

**解决问题**：`[@sec:xxx]` 等引用标签在 MkDocs 中可能无法解析时，清理掉避免显示原始语法。

#### (5) `table_captions.py` — Pandoc 风格表格标题

**解决问题**：MkDocs 默认不支持 `Table: 标题` 语法。

```markdown
Table: 术语说明 {#tbl:glossary}

| 缩写 | 全称 |
| BPU  | Branch Prediction Unit |
```

→ 渲染为带 `<caption>` 的 HTML 表格。

#### (6) `test_crossref_simple.py` — 单元测试

确保交叉引用扩展的正确性。

### 2.4 自定义主题层

位于 `utils/custom_theme/`，通过 Material 主题的 `custom_dir` 机制非侵入式覆盖：

```
custom_theme/
├── main.html                    # 基础模板（ReadTheDocs 版本选择器集成）
├── partials/
│   ├── header.html              # 顶栏增加"回到首页"按钮
│   └── alternate.html           # 语言切换器（切换时保持当前页）
├── assets/
│   ├── stylesheets/
│   │   └── table_fix.css        # 修复 Material 主题表格样式
│   └── javascripts/
│       ├── mathjax.js           # MathJax 数学公式渲染
│       └── readthedocs.js       # RTD 版本下拉框集成
```

**`header.html`** — 顶栏加"回到首页"按钮：

```yaml
# mkdocs-zh.yml 配置
extra:
  back_to_home:
    url: https://docs.xiangshan.cc/
    title: 回到香山文档首页
```

**`alternate.html`** — 语言切换保持当前页：

当用户在中文版的 `frontend/BPU/TAGE-SC.html` 点击"English"，跳转到英文版的同路径页面，而非首页。

---

## 三、PDF 构建管线：Pandoc + XeLaTeX

### 3.1 为什么选 Pandoc（而非 MkDocs-to-PDF）

| 方案 | 优点 | 缺点 |
|---|---|---|
| mkdocs-to-pdf | 简单，一条命令 | 排版质量差，中文字体难控制 |
| Pandoc → XeLaTeX | 专业排版，CTEX 中文支持 | 配置复杂 |
| WeasyPrint | CSS 控制精确 | 中文排版弱 |

香山选 Pandoc + XeLaTeX 的理由：
1. **ctexbook 文档类**：成熟的中文排版方案（字体、断行、章节格式）
2. **pandoc-crossref**：与 LaTeX 原生的交叉引用系统无缝集成
3. **Lua 过滤器**：灵活的文档处理管道

### 3.2 Makefile 构建流程详解

Makefile 使用 `define` + `$(foreach)` 实现多语言模板化构建：

```makefile
# 1. 收集源文件
SRCS_zh := $(shell find docs/zh -name '*.md')          # 所有中文 Markdown
SVG_FIGS_zh := $(shell find docs/zh -name '*.svg')     # 所有 SVG 图

# 2. SVG → PDF 转换（LaTeX 不支持 SVG）
build/docs/zh/%.pdf: docs/zh/%.svg
    rsvg-convert -f pdf -o $@ $<

# 3. 序言页 Markdown → LaTeX
preface-zh.tex: docs/zh/index.md
    pandoc $< $(PANDOC_FLAGS_zh) -o $@

# 4. 主文档 Markdown → LaTeX
xiangshan-design-doc-zh.tex: preface-zh.tex pandoc-main-zh.md $(SRCS_zh) $(DEPS)
    pandoc pandoc-main-zh.md $(PANDOC_FLAGS_zh) $(PANDOC_LATEX_FLAGS_zh) -s -o $@

# 5. LaTeX → PDF（编译三次以解析交叉引用）
xiangshan-design-doc-zh.pdf: xiangshan-design-doc-zh.tex $(PDF_FIGS_zh)
    xelatex $<
    xelatex $<     # 第二遍：解析 \ref, \cite
    xelatex $<     # 第三遍：稳定交叉引用
```

### 3.3 Pandoc Flags 解析

```makefile
PANDOC_FLAGS += --from=markdown+table_captions+multiline_tables+grid_tables+header_attributes-implicit_figures
PANDOC_FLAGS += --table-of-contents          # 自动生成目录
PANDOC_FLAGS += --number-sections            # 章节自动编号
PANDOC_FLAGS += --lua-filter=include-files.lua        # 文件包含
PANDOC_FLAGS += --metadata=include-auto
PANDOC_FLAGS += --lua-filter=utils/pandoc_filters/replace_variables.lua   # 变量替换
PANDOC_FLAGS += --lua-filter=utils/pandoc_filters/remove_md_links.lua     # 移除 .md 链接
PANDOC_FLAGS += --filter pandoc-crossref                # 交叉引用
PANDOC_FLAGS += --variable=version:"$(VERSION)"         # 注入 git 版本
PANDOC_FLAGS += --metadata-file=docs/variables-zh.yml   # 语言特定变量
```

**Markdown 方言选择**：

```makefile
--from=markdown+table_captions+multiline_tables+grid_tables+header_attributes-implicit_figures
```

| 扩展 | 用途 |
|---|---|
| `+table_captions` | 支持 `Table: 标题` 语法 |
| `+multiline_tables` | 多行表格（Pandoc 扩展） |
| `+grid_tables` | Grid 表格 `+---+---+` |
| `+header_attributes` | 支持 `{#fig:xxx}` 属性 |
| `-implicit_figures` | 禁用隐式图片编号（用 crossref 替代） |

### 3.4 三个 Lua 过滤器

#### (1) `replace_variables.lua` — 变量替换（Pandoc 端）

与 MkDocs 的 `replace_variables.py` 功能相同，确保 PDF 和网站使用相同的变量系统。

```lua
-- 读取 metadata 中的 replace_variables
-- 在文本中查找 {{varname}} 模式
-- 替换为对应值
```

#### (2) `svg_to_pdf.lua` — SVG 转 PDF 路径

```lua
-- 仅在 LaTeX 输出时生效
-- 将 image.svg 替换为 image.pdf
-- 配合 rsvg-convert 预转换的 PDF 文件
```

#### (3) `remove_md_links.lua` — 清理 Markdown 互链

```lua
-- 检测 [text](xxx.md) 格式的链接
-- 在 PDF 中去除链接外壳，只保留文字
-- 因为 PDF 是单页连续文档，无需页面间跳转
```

### 3.5 LaTeX 模板解析

`utils/template.tex` 基于 `ctexbook` 文档类，关键设计：

**字体配置**：

```latex
\documentclass[5pt,a4paper]{ctexbook}
\setCJKmainfont{Source Han Serif CN}     % 思源宋体（正文）
\setCJKsansfont{Source Han Sans CN}      % 思源黑体（标题）
```

**页面布局**：

```latex
\usepackage[top=25mm, bottom=25mm, left=20mm, right=20mm]{geometry}
```

**标题页**（多行标题 + 处理器名 + Logo）：

```latex
\begin{titlepage}
  {\LARGE $title-line1$}           % "香山开源处理器"
  {\LARGE $title-line2$}           % "设计文档"
  {\large $replace_variables.processor_name$}  % "昆明湖 V2R2"
  {\large 版本: $version$}
  \includegraphics{utils/figs/XiangShan-Community}  % Logo
\end{titlepage}
```

**浮动控制**：

```latex
\usepackage{placeins}  % \FloatBarrier — 防止图片跨章节浮动
```

---

## 四、双管线兼容：网站与 PDF 的语法统一

### 4.1 核心挑战

MkDocs 和 Pandoc 是两套完全不同的构建系统，但源文件只有一份 Markdown。香山的解法是：

```
                    Markdown 源文件
                    (统一语法)
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
         MkDocs 构建            Pandoc 构建
         ├ Python 扩展           ├ Lua 过滤器
         │ 处理 Pandoc 语法      │ 处理 MkDocs 语法
         └ 输出 HTML             └ 输出 LaTeX/PDF
```

### 4.2 兼容对照表

| Markdown 语法 | MkDocs 处理 | Pandoc 处理 |
|---|---|---|
| `{{variable}}` | `replace_variables.py` 读 YAML 替换 | `replace_variables.lua` 读 metadata 替换 |
| `[@fig:xxx]` | `crossref.py` 生成 HTML 锚点链接 | `pandoc-crossref` 生成 LaTeX `\ref{}` |
| `![img](path){#fig:xxx}` | `crossref.py` 识别 ID | `pandoc-crossref` 识别属性 |
| `Table: 标题` | `table_captions.py` 插入 `<caption>` | Pandoc 原生支持 |
| ` ```{.include} ` | `remove_include.py` 静默移除 | `include-files.lua` 展开合并 |
| `![img](x.svg)` | 浏览器原生渲染 SVG | `svg_to_pdf.lua` 转换为 PDF 引用 |
| `[text](page.md)` | MkDocs 正常处理为页面链接 | `remove_md_links.lua` 移除链接 |
| `$math$` | `arithmatex` + MathJax | Pandoc 原生 LaTeX 数学 |

### 4.3 设计精髓

**同一个概念，两套实现，一份源文件**：

```
变量替换:   Python 扩展 (MkDocs) ←→ Lua 过滤器 (Pandoc)
交叉引用:   crossref.py (MkDocs) ←→ pandoc-crossref (Pandoc)
文件包含:   remove_include (MkDocs 忽略) ←→ include-files.lua (Pandoc 展开)
SVG 图:    浏览器渲染 (MkDocs) ←→ rsvg-convert + svg_to_pdf.lua (Pandoc)
```

这种"**适配器模式**"让作者只需写标准 Markdown + 少量 Pandoc-crossref 语法，完全不需要关心输出目标。

---

## 五、质量保证体系

### 5.1 Markdown 格式检查

**markdownlint-cli2**（`.markdownlint.yml`）：

```yaml
MD013: false           # 不限制行长度（中文行长度无意义）
MD033:
  allowed_elements:
    - br               # 仅允许 <br> 标签
```

**lint-md**（中文专项检查）：
- 中英文之间空格检查
- 中文标点使用检查
- 专有名词大小写检查

### 5.2 容器化 Lint 环境

```dockerfile
# tools/lint/Dockerfile
FROM node:current-alpine
RUN apk add bash && \
    npm install -g @lint-md/cli && \
    npm install -g markdownlint-cli2
```

```bash
# tools/lint/run-lint.sh
AUTOFIX=${AUTOFIX:-true}
markdownlint-cli2 ${GENERAL_FLAGS} ${TARGET}
lint-md ${GENERAL_FLAGS} ${TARGET}
```

运行方式：

```bash
# 本地 Docker 运行
docker build -t xiangshan-design-doc-linter -f tools/lint/Dockerfile .
docker run -v $(pwd):/work xiangshan-design-doc-linter tools/lint/run-lint.sh
```

### 5.3 CI 自动构建

**`build-pandoc.yml`** — 每次 push/PR 自动构建：

```yaml
strategy:
  matrix:
    lang: [zh, en]         # 中英文并行构建

steps:
  - uses: actions/checkout@v4
    with:
      submodules: true      # 拉取 utils 子模块
      fetch-tags: true      # 获取 git tag（用于版本号）

  - run: |
      make pdf-one LANG=${{ matrix.lang }}
      make pdf-one LANG=${{ matrix.lang }} TWOSIDE=1   # 同时生成双面打印版

  - uses: actions/upload-artifact@v4
    with:
      name: xiangshan-design-doc-${{ matrix.lang }}
      path: |
        xiangshan-design-doc-${{ matrix.lang }}.pdf
        xiangshan-design-doc-twoside-${{ matrix.lang }}.pdf
```

关键细节：
- 使用 `ghcr.io/openxiangshan/docs-utils:latest` 容器镜像（预装 Pandoc + LaTeX + 字体）
- `fetch-tags: true` 确保 `git describe --always` 能获取版本信息
- 同时生成普通版和双面打印版（`TWOSIDE=1`）

**`release.yml`** — 手动触发版本发布：

```yaml
on:
  workflow_dispatch:
    inputs:
      release_name:
        description: 'Release name (tag name)'

jobs:
  create-release:    # 1. 创建 Git Tag
  trigger-build:     # 2. 调用 build-pandoc.yml 构建
  publish-release:   # 3. 上传 PDF 到 GitHub Release
```

---

## 六、部署方案

### 6.1 ReadTheDocs（网站）

`.readthedocs.yaml`：

```yaml
version: 2
submodules:
  include: all           # 拉取 utils 子模块

build:
  os: ubuntu-24.04
  tools:
    python: "3.13"

mkdocs:
  configuration: mkdocs.yml    # 入口（环境变量分发语言）

python:
  install:
  - requirements: utils/requirements.txt
```

ReadTheDocs 通过设置 `MKDOCS_YML_FILE` 环境变量，分别构建中文和英文站点：

- `https://docs.xiangshan.cc/projects/design/zh-cn/latest/`
- `https://docs.xiangshan.cc/projects/design/en/latest/`

### 6.2 GitHub Releases（PDF）

```
Release v2025.01
├── xiangshan-design-doc-zh.pdf          # 中文单面版
├── xiangshan-design-doc-twoside-zh.pdf  # 中文双面打印版
├── xiangshan-design-doc-en.pdf          # 英文单面版
└── xiangshan-design-doc-twoside-en.pdf  # 英文双面打印版
```

---

## 七、容器化构建环境

### 7.1 `utils/Dockerfile`

```dockerfile
FROM ubuntu:noble
COPY . /app
RUN /app/dependency.sh && apt clean
WORKDIR /work
```

### 7.2 `utils/dependency.sh` — 完整环境安装

```bash
# 1. Pandoc 3.4
wget https://github.com/jgm/pandoc/releases/download/3.4/pandoc-3.4-linux-amd64.tar.gz

# 2. pandoc-crossref v0.3.18.0
wget https://github.com/lierdakil/pandoc-crossref/releases/download/v0.3.18.0/pandoc-crossref-Linux-X64.tar.gz

# 3. include-files.lua
wget https://github.com/pandoc/lua-filters/releases/download/latest/include-files.lua

# 4. TinyTeX (最小化 LaTeX 发行版)
wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz

# 5. LaTeX 宏包
tlmgr install ctex setspace subfig caption textpos tocloft titlesec multirow placeins

# 6. SVG → PDF 转换器
apt install librsvg2-bin

# 7. 中文字体
# Source Han Sans CN (Regular, Bold)
# Source Han Serif CN (Regular, Bold)
```

---

## 八、技术栈方法论

### 8.1 方法论一：双管线统一源

**原则**：一套 Markdown 源文件，通过适配器同时服务网站（MkDocs）和 PDF（Pandoc）。

**实现**：每个 Pandoc 特有语法，都配有对应的 MkDocs Python 扩展来兼容。

**价值**：作者无需关心输出格式，写一次，到处发布。

### 8.2 方法论二：配置继承 + 变量外部化

**原则**：共享配置抽到 base，差异通过继承 + 变量解决。

```
mkdocs-base.yml          ← 共享：主题、扩展、插件
    │
    ├── mkdocs-zh.yml    ← 差异：docs_dir、nav、variables-zh.yml
    └── mkdocs-en.yml    ← 差异：docs_dir、nav、variables-en.yml
```

变量文件集中管理版本信息，模板中用 `{{processor_name}}` 引用。

### 8.3 方法论三：构建工具链独立仓库

**原则**：构建基础设施（扩展、过滤器、模板、字体）抽为独立 Git 仓库，通过子模块引用。

```
docs-utils 仓库
├── MkDocs 基础配置
├── Python 扩展（6个）
├── Lua 过滤器（3个）
├── LaTeX 模板
├── Material 主题定制
├── Docker 构建环境
├── 安装脚本
└── 品牌资源（Logo）
```

**价值**：
- 多个文档仓库（User Guide、Design Doc 等）复用同一套工具
- 工具链更新只需推子模块，各仓库同步
- 容器化保证构建环境一致

### 8.4 方法论四：容器化保证可复现

**原则**：构建环境完全容器化，消除"我机器上能构建"问题。

- `utils/Dockerfile` → Pandoc + LaTeX + 字体环境
- `tools/lint/Dockerfile` → Lint 环境
- GitHub Actions 使用 `ghcr.io/openxiangshan/docs-utils:latest`

### 8.5 方法论五：CI/CD 自动化闭环

**原则**：提交即构建，发布一键完成。

```
开发者提交 Markdown
        │
        ▼
GitHub Actions 自动触发
├── Lint 检查（可选）
├── PDF 构建（中英文 × 单面双面 = 4 个文件）
└── 上传 Artifact
        │
        ▼
手动触发 Release
├── 创建 Git Tag
├── 调用构建 Workflow
└── 上传 PDF 到 GitHub Release
        │
        ▼
ReadTheDocs 自动部署
└── 检测 push → 拉取子模块 → mkdocs build → 发布
```

### 8.6 方法论六：中文技术文档专项优化

**原则**：每个环节都针对中文文档做了专门优化。

| 环节 | 优化 |
|---|---|
| 搜索 | jieba 中文分词 |
| 排版 | ctexbook + 思源宋体/黑体 |
| 检查 | lint-md 中文专项 lint |
| PDF | XeLaTeX（原生 Unicode/CJK 支持） |
| 变量 | 中文/英文独立变量文件 |

---

## 九、方法论总结

| # | 方法论 | 核心做法 | 解决的问题 |
|---|---|---|---|
| 1 | 双管线统一源 | MkDocs + Pandoc 共用 Markdown + 适配器 | 一写多出，避免维护两份文档 |
| 2 | 配置继承 + 变量化 | base 配置 + 语言差异 + YAML 变量 | 多语言配置不重复 |
| 3 | 工具链独立仓库 | docs-utils Git 子模块 | 多仓库复用，版本锁定 |
| 4 | 容器化可复现 | Docker 构建环境 | 消除环境差异 |
| 5 | CI/CD 自动化 | GitHub Actions 构建 + Release | 提交即构建，发布一键完成 |
| 6 | 中文专项优化 | jieba/ctex/lint-md/XeLaTeX | 中文技术文档的搜索、排版、检查 |

**一句话总结**：香山的技术栈选型遵循"**一份源文件、双管线输出、容器化构建、自动化发布**"的原则，通过适配器模式弥合 MkDocs 与 Pandoc 的语法差异，用子模块管理共享工具链，实现了中文硬件设计文档的工业化生产流程。
