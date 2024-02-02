TEXMFHOME = $(shell kpsewhich -var-value=TEXMFHOME)
PKG_NAME = cooklang
LUA_KPSEHOME = $(TEXMFHOME)/scripts/lua/$(PKG_NAME)
TEX_KPSEHOME = $(TEXMFHOME)/tex/latex/$(PKG_NAME)
LUA_CONTENT = $(wildcard src/*.lua)
TEX_CONTENT = $(wildcard latex/*.sty)
BUILD_DIR = build
BUILD_DEST = $(BUILD_DIR)/$(PKG_NAME)
ZIP_NAME = $(PKG_NAME).zip
DOC_NAME = $(PKG_NAME)-doc
DOC_PDF  = $(DOC_NAME).pdf
DOC_TEX  = $(DOC_NAME).tex

all: latex/$(DOC_PDF) src/cooklang-unicode-data.lua 

latex/$(DOC_PDF): latex/$(DOC_TEX) $(LUA_CONTENT) $(TEX_CONTENT)
	cd latex && lualatex $(DOC_TEX)

src/cooklang-unicode-data.lua: tools/make_unicode_data.lua
	texlua $< > $@


install:
	mkdir -p $(LUA_KPSEHOME)
	mkdir -p $(TEX_KPSEHOME)
	cp $(LUA_CONTENT) $(LUA_KPSEHOME)
	cp $(TEX_CONTENT) $(TEX_KPSEHOME)

build: $(LUA_CONTENT) $(TEX_CONTENT)
	rm -rf $(BUILD)
	mkdir -p $(BUILD_DEST)
	cp $(LUA_CONTENT) $(TEX_CONTENT) $(BUILD_DEST)
	cd $(BUILD_DIR) && zip -r $(ZIP_NAME) $(PKG_NAME)
	
test:
	busted spec/test-cooklang.lua
