TEXMFHOME = $(shell kpsewhich -var-value=TEXMFHOME)
LUA_KPSEHOME = $(TEXMFHOME)/scripts/lua/cooklang
TEX_KPSEHOME = $(TEXMFHOME)/tex/latex/cooklang
LUA_CONTENT = $(wildcard src/*.lua)
TEX_CONTENT = $(wildcard latex/*.sty)


install:
	mkdir -p $(LUA_KPSEHOME)
	mkdir -p $(TEX_KPSEHOME)
	cp $(LUA_CONTENT) $(LUA_KPSEHOME)
	cp $(TEX_CONTENT) $(TEX_KPSEHOME)
