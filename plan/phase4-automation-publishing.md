# Phase 4 — 自动化与发布

## 方法论

本阶段采用 **持续交付（Continuous Delivery）** 与 **文档版本化（Documentation Versioning）** 方法论：

- **持续交付（Continuous Delivery）**：文档的构建、检查和发布应该完全自动化，开发者只需要推送 Markdown 文件，CI 系统自动完成 lint → build → deploy 全流程。零手动操作，零人工干预，确保发布的一致性和可重复性。
- **文档版本化（Documentation Versioning）**：设计文档应与代码版本绑定。每次 CUTE 硬件版本更新时，文档自动生成对应版本的快照，支持读者查看历史版本。
- **多格式发布（Multi-Format Publishing）**：同一份 Markdown 源文件同时输出为在线网站（GitHub Pages）和离线 PDF，满足不同使用场景。
- **渐进增强（Progressive Enhancement）**：先确保基本的自动化流程跑通，再逐步添加高级功能（如自动 PDF 发布、版本选择器等）。

---

## 整体框架进度

```
Phase 0 ─── [已完成] 框架搭建
Phase 1 ─── [已完成] 核心文档（overview/ + hardware/）
Phase 2 ─── [已完成] 指令集与数据类型
Phase 3 ─── [已完成] 软件与测试
Phase 4 ─── [当前阶段] 自动化与发布
```

**当前进度：0%** — Phase 0 已创建 CI 配置骨架，但尚未实际验证。Phase 4 将完善 CI 流水线、配置 PDF 生成、部署 GitHub Pages。

完成后将达到：推送 Markdown 到 master 分支后，自动 lint → build → deploy 到 GitHub Pages；手动触发可生成 PDF 附件发布到 GitHub Releases。

---

## 实施细节

### 步骤 4.1 — 完善 CI 流水线

**方法论：持续交付**

Phase 0 创建的 `.github/workflows/ci.yml` 需要在 Phase 4 中完善和验证。

#### 4.1.1 Lint 流水线

```yaml
# .github/workflows/ci.yml — lint job
name: CI

on:
  push:
    branches: [master]
    paths:
      - 'docs/**'
      - 'mkdocs.yml'
      - '.markdownlint.yml'
  pull_request:
    branches: [master]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install markdownlint
        run: npm install -g markdownlint-cli2

      - name: Run Markdown lint
        run: markdownlint-cli2 "docs/**/*.md"

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.13'

      - name: Install MkDocs dependencies
        run: |
          pip install mkdocs-material
          pip install mkdocs-mermaid2-plugin
          pip install mkdocs-markdownextradata-plugin

      - name: Build site (strict mode)
        run: mkdocs build --strict
```

**要点：**
- `mkdocs build --strict` 会将警告视为错误，确保无断链
- 仅在文档相关文件变更时触发，避免无关 push 浪费 CI 资源

#### 4.1.2 链接检查（可选增强）

```yaml
      - name: Check links
        uses: lycheeverse/lychee-action@v2
        with:
          args: --exclude-mail "docs/**/*.md"
```

---

### 步骤 4.2 — GitHub Pages 部署

**方法论：持续交付 — 推送即部署**

#### 4.2.1 自动部署流程

```yaml
# .github/workflows/ci.yml — deploy job
  deploy:
    needs: lint
    if: github.ref == 'refs/heads/master' && github.event_name == 'push'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pages: write
      id-token: write

    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.13'

      - name: Install dependencies
        run: |
          pip install mkdocs-material
          pip install mkdocs-mermaid2-plugin

      - name: Build site
        run: mkdocs build

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: site

      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

#### 4.2.2 仓库设置

需要在 GitHub 仓库设置中完成：
1. Settings → Pages → Source 设为 "GitHub Actions"
2. 确认 `GITHUB_TOKEN` 有 `pages: write` 权限

#### 4.2.3 自定义域名（可选）

如果需要自定义域名：
1. 在 `docs/` 下创建 `CNAME` 文件
2. 在域名注册商配置 DNS 记录
3. 在 mkdocs.yml 中添加 `custom_url` 配置

---

### 步骤 4.3 — PDF 生成自动化

**方法论：多格式发布 + 渐进增强**

#### 4.3.1 PDF 生成脚本

创建 `tools/build-pdf.sh`：

```bash
#!/bin/bash
set -e

OUTPUT_DIR="build"
mkdir -p "$OUTPUT_DIR"

# 收集所有 Markdown 文件（按导航顺序）
DOCS=$(cat <<'EOF'
docs/index.md
docs/overview/introduction.md
docs/overview/architecture-overview.md
docs/overview/getting-started.md
docs/hardware/compute-engine/mte.md
docs/hardware/compute-engine/reduce-pe.md
docs/hardware/compute-engine/after-ops.md
docs/hardware/memory-system/scratchpads.md
docs/hardware/memory-system/data-controllers.md
docs/hardware/memory-system/memory-loaders.md
docs/hardware/control-logic/task-controller.md
docs/hardware/control-logic/cute2ygjk.md
docs/instruction-set/instruction-encoding.md
docs/instruction-set/fusion-operators.md
docs/datatypes/precision-formats.md
docs/datatypes/quantization.md
docs/software/test-framework.md
docs/software/benchmark-results.md
docs/appendix/glossary.md
docs/appendix/references.md
EOF
)

pandoc $DOCS \
  --pdf-engine=xelatex \
  -V mainfont="Noto Sans CJK SC" \
  -V sansfont="Noto Sans CJK SC" \
  -V monofont="JetBrains Mono" \
  -V geometry:margin=1in \
  -V fontsize=11pt \
  -V documentclass=article \
  -V colorlinks=true \
  -V linkcolor=blue \
  -V urlcolor=blue \
  -V toc-title="目录" \
  --toc \
  --toc-depth=3 \
  --filter pandoc-crossref \
  --resource-path=docs \
  -o "$OUTPUT_DIR/cute-design-doc.pdf"

echo "PDF generated: $OUTPUT_DIR/cute-design-doc.pdf"
```

#### 4.3.2 PDF 发布到 GitHub Releases

```yaml
# .github/workflows/release.yml
name: Release PDF

on:
  push:
    tags:
      - 'doc-v*'

jobs:
  build-pdf:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install TeX Live
        run: |
          sudo apt-get update
          sudo apt-get install -y texlive-xetex texlive-lang-chinese fonts-noto-cjk

      - name: Install Pandoc
        run: |
          wget -q https://github.com/jgm/pandoc/releases/download/3.6/pandoc-3.6-1-amd64.deb
          sudo dpkg -i pandoc-3.6-1-amd64.deb

      - name: Build PDF
        run: bash tools/build-pdf.sh

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: build/cute-design-doc.pdf
          generate_release_notes: true
```

**触发方式：**
```bash
git tag doc-v0.1
git push origin doc-v0.1
```

---

### 步骤 4.4 — 文档版本管理

**方法论：文档版本化**

#### 4.4.1 变量外部化

创建 `docs/variables.yml`：

```yaml
cute_version: "0.1"
doc_version: "0.1"
doc_date: "2026-04"
chisel_version: "6.x"
riscv_isa: "RV64GC"
license: "CC BY 4.0"
```

在 mkdocs.yml 中启用 `markdownextradata` 插件：

```yaml
plugins:
  - search
  - mermaid2
  - markdownextradata:
      data: docs
```

在文档中使用变量：

```markdown
CUTE 版本 {{ cute_version }}，基于 Chisel {{ chisel_version }} 实现。
```

#### 4.4.2 版本快照策略

| 版本号 | 触发条件 | 发布方式 |
|--------|---------|---------|
| `doc-v0.1` | 初始文档完成 | GitHub Release + PDF |
| `doc-v0.2` | Phase 1-2 文档完成 | GitHub Release + PDF |
| `doc-v1.0` | 全部文档完成 | GitHub Release + PDF |
| `doc-v1.x` | 后续增量更新 | GitHub Release + PDF |

#### 4.4.3 变更记录

`docs/appendix/changelog.md` 维护文档变更历史：

```markdown
# 文档变更记录

## v0.1 (YYYY-MM-DD)
### 新增
- 初始框架搭建
- overview/ 和 hardware/ 核心文档
```

---

### 步骤 4.5 — 附录完善

#### 4.5.1 `docs/appendix/glossary.md` — 术语表

```markdown
# 术语表

| 术语 | 全称 | 说明 |
|------|------|------|
| CUTE | CPU Unified Tensor Engine | CPU 集成张量加速器 |
| MTE  | Matrix Tensor Engine | 矩阵张量引擎 |
| PE   | Processing Element | 处理单元 |
| MAC  | Multiply-Accumulate | 乘加运算 |
| RoCC | Rocket Custom Coprocessor | Rocket 自定义协处理器接口 |
| YGJK | — | CUTE 使用的自定义指令扩展名 |
| BF16 | Brain Float 16 | 16 位脑浮点 |
| MXFP | Microscaling FP | 微缩放浮点 |
| ...  | ...  | ...  |
```

#### 4.5.2 `docs/appendix/references.md` — 参考文献

```markdown
# 参考文献

## 规范与标准
- RISC-V Privileged Specification v1.12
- IEEE 754-2019 Floating-Point Standard
- MXFP Specification (OCP)
- ...

## 论文
- [CUTE 相关论文]
- ...

## 开源项目
- XiangShan Design Doc — 文档组织参考
- Rocket Chip — RoCC 接口定义
- Chisel — 硬件描述语言
- MkDocs Material — 文档框架
```

---

### 步骤 4.6 — 最终验证与发布

**方法论：渐进增强 — 先确保基本流程，再增强**

验证清单：

#### 基础验证
- [ ] `make lint` 全部通过
- [ ] `make build` 无警告无错误
- [ ] `mkdocs serve` 本地预览正常
- [ ] 所有内部链接有效（`--strict` 模式）
- [ ] 所有图表正确渲染（Mermaid、WaveDrom）

#### CI 验证
- [ ] Push 到 master 后 CI 自动触发
- [ ] Lint job 通过
- [ ] Build job 通过
- [ ] Deploy job 成功部署到 GitHub Pages
- [ ] GitHub Pages 可正常访问

#### PDF 验证
- [ ] `make pdf` 本地生成 PDF 成功
- [ ] 中文字体正确渲染
- [ ] 图表在 PDF 中可见
- [ ] 目录和交叉引用正确

#### 内容验证
- [ ] 所有文档无 TODO 占位
- [ ] 数据类型支持矩阵完整
- [ ] 指令速查表完整
- [ ] 术语表覆盖所有关键术语
- [ ] 参考文献完整

---

## 产出物

| 产出物 | 路径 |
|---|---|
| 完善的 CI 配置 | `.github/workflows/ci.yml` |
| Release 工作流 | `.github/workflows/release.yml` |
| PDF 构建脚本 | `tools/build-pdf.sh` |
| 变量配置 | `docs/variables.yml` |
| 术语表 | `docs/appendix/glossary.md` |
| 参考文献 | `docs/appendix/references.md` |
| 变更记录 | `docs/appendix/changelog.md` |
| 在线文档站点 | GitHub Pages |
| PDF 文档 | GitHub Releases 附件 |

---

## 依赖与风险

| 项目 | 说明 |
|---|---|
| **依赖：Phase 0-3 全部完成** | 所有文档内容就绪后才能进行最终发布 |
| **依赖：GitHub Pages 权限** | 需要仓库管理员配置 Pages 权限 |
| **依赖：XeLaTeX + 中文字体** | PDF 生成需要安装 TeX Live 和中文字体 |
| **依赖：Pandoc 版本** | 需要较新版本的 Pandoc（≥ 3.0）以支持高级 Markdown 特性 |
| **风险：PDF 排版问题** | Markdown → LaTeX → PDF 转换可能有排版问题（表格溢出、图片位置等），需要调优 |
| **风险：CI 资源限制** | GitHub Actions 免费额度有限，PDF 生成耗时较长（安装 TeX Live 约 5-10 分钟） |
| **风险：mkdocs-mermaid2 兼容性** | Mermaid 插件与 mkdocs-material 可能有版本冲突 |
