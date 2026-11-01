# Build and install the howdy-git Arch package from this checkout.
#   make          build the package
#   make install  build, then install it (sudo scans your face)
#   make doctor   run `howdy doctor` on the installed copy

PKG = $(shell ls -t $(CURDIR)/howdy-git-*.pkg.tar.zst 2>/dev/null | head -1)

.PHONY: all build install doctor clean

all: build

build:
	makepkg -f --noconfirm

install: build
	sudo pacman -U --noconfirm $(PKG)

doctor:
	sudo howdy doctor

clean:
	rm -rf src pkg
