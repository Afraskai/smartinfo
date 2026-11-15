PREFIX  ?= $(HOME)/.local
BINDIR  ?= $(PREFIX)/bin
VERSION := $(shell sed -n 's/^VERSION="\(.*\)"/\1/p' smartinfo)

.PHONY: help install uninstall test lint check release

help:
	@echo "smartinfo $(VERSION)"
	@echo
	@echo "  make install      nach $(DESTDIR)$(BINDIR) installieren"
	@echo "  make uninstall    wieder entfernen"
	@echo "  make test         Testsuite ausfuehren"
	@echo "  make lint         shellcheck"
	@echo "  make check        lint + tests"
	@echo "  make release      Hinweis zum Anlegen eines Release-Tags"
	@echo
	@echo "Varianten: make install PREFIX=/usr/local"

install:
	install -Dm755 smartinfo "$(DESTDIR)$(BINDIR)/smartinfo"
	@echo "installiert: $(DESTDIR)$(BINDIR)/smartinfo"

uninstall:
	@if [ -e "$(DESTDIR)$(BINDIR)/smartinfo" ]; then \
		rm -f "$(DESTDIR)$(BINDIR)/smartinfo"; \
		echo "entfernt: $(DESTDIR)$(BINDIR)/smartinfo"; \
	else \
		echo "nicht installiert: $(DESTDIR)$(BINDIR)/smartinfo"; \
	fi

test:
	./tests/run.sh

lint:
	shellcheck smartinfo install.sh tests/run.sh

check: lint test

release:
	@echo "Version steht auf $(VERSION). Tag anlegen:"
	@echo "  git tag -a v$(VERSION) -m 'smartinfo $(VERSION)'"
	@echo "  git push origin main --tags"
