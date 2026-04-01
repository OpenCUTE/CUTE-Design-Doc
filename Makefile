.PHONY: serve build pdf lint clean

serve:
	mkdocs serve

build:
	mkdocs build

pdf:
	@mkdir -p build
	pandoc docs/index.md \
	  docs/overview/*.md \
	  docs/hardware/compute-engine/*.md \
	  docs/hardware/memory-system/*.md \
	  docs/hardware/control-logic/*.md \
	  docs/hardware/integration/*.md \
	  docs/instruction-set/*.md \
	  docs/datatypes/*.md \
	  docs/software/*.md \
	  docs/appendix/*.md \
	  --pdf-engine=xelatex \
	  -V mainfont="Noto Sans CJK SC" \
	  -V monofont="JetBrains Mono" \
	  -V geometry:margin=1in \
	  -V fontsize=11pt \
	  --filter pandoc-crossref \
	  --resource-path=docs \
	  -o build/cute-design-doc.pdf

lint:
	markdownlint-cli2 "docs/**/*.md"

clean:
	rm -rf site/ build/
