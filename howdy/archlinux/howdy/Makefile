# Build and install the howdy-git Arch package from this checkout.
#   make          build the package
#   make install  build, then install it (sudo scans your face)
#   make check    build, then verify the package contents
#   make test     run the unit tests
#   make doctor   run `howdy doctor` on the installed copy

PKG = $(shell ls -t $(CURDIR)/howdy-git-*.pkg.tar.zst 2>/dev/null | head -1)

.PHONY: all build install check test doctor clean

all: build

build:
	makepkg -f --noconfirm

install: build
	sudo pacman -U --noconfirm $(PKG)

check: build
	./check-package.sh $(PKG)

test:
	python3 -m unittest discover -s ../../../tests -v

doctor:
	sudo howdy doctor

clean:
	rm -rf src pkg
