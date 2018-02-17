# TODO: do this from nix cp
CABAL_BUILD_DIR_B:=/home/srid/code/slownews/dist-newstyle/build/x86_64-linux/ghc-8.0.2/backend-1.0.0/c/slownews-backend/build/slownews-backend/slownews-backend
CABAL_BUILD_DIR_F:=./dist-ghcjs/build/x86_64-linux/ghcjs-0.2.1/frontend-1.0.0.0/c/slownews-frontend/build/slownews-frontend/slownews-frontend.jsexe
OUTPUT_DIR:=dist-makefile

all:	nixbuild	nixrun
	@true

nixbuild:
	nix-build

nixrun:
	./result/ghc/backend/bin/backend

# Compile frontend
# From emacs: SPC p c.
f:
	rm -f ${OUTPUT_DIR}/static
	nix-shell -A shells.ghcjs --run "cabal --project-file=cabal-ghcjs.project --builddir=dist-ghcjs new-build frontend" default.nix
	mkdir -p ${OUTPUT_DIR}
	ln -sf `pwd`/${CABAL_BUILD_DIR_F} ${OUTPUT_DIR}/static

# Interactive frontend compilation
fi:
	nix-shell -A shells.ghc --run "cabal new-repl frontend" default.nix

# Compile backend
b:
	nix-shell -A shells.ghc --run "cabal new-build backend" default.nix
	mkdir -p ${OUTPUT_DIR}/
	cp ${CABAL_BUILD_DIR_B} ${OUTPUT_DIR}/
	cp -v backend/config/config.json ${OUTPUT_DIR}/

# Run backend (assuming frontend is also built)
r:
	cd ${OUTPUT_DIR}/ && ./slownews-backend

dist:
	zip -r dist.zip dist-makefile/ -x *.jsexe*

# Run stylish-haskell over modified files
stylish:
	nix-shell -p haskellPackages.stylish-haskell --run "stylish-haskell -i `git diff --name-only | grep .hs`" default.nix
