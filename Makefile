# ooattest v0.2.0 Makefile

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/ooattest

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.2.0)

.PHONY: build check line-cap file-law academy density verify clean test package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/ooattest-linux-x86_64
	@sha256sum dist/ooattest-linux-x86_64 > dist/ooattest-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/ooattest-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot" | grep -v "/dist/" | grep -v "/.ooda-cache/"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
			continue; \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*" -not -path "./qa*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== testing --help ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@echo "=== testing --version ==="
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@echo "=== testing TPM status query ==="
	@./$(BIN) --status | grep -q "TPM" && echo "PASS: --status"
	@./$(BIN) --status --json | grep -q '"version"' && echo "PASS: --status --json"
	@echo "=== testing PCR table inspection ==="
	@./$(BIN) --pcrs | grep -q "PCR-00" && echo "PASS: --pcrs"
	@./$(BIN) --pcrs --json | grep -q '"index":0' && echo "PASS: --pcrs --json"
	@echo "=== testing single PCR filter ==="
	@./$(BIN) --pcr 7 | grep -q "PCR-07" && echo "PASS: --pcr 7"
	@echo "=== testing baseline verification (match) ==="
	@rm -rf /tmp/ooattest-test && mkdir -p /tmp/ooattest-test
	@printf "PCR-00: 3a4f128bcde90123456789abcdef0123456789abcdef0123456789abcdef0123\n" > /tmp/ooattest-test/golden.txt
	@./$(BIN) --verify /tmp/ooattest-test/golden.txt | grep -q "TRUSTED" && echo "PASS: verify golden"
	@echo "=== testing baseline verification (tampered) ==="
	@printf "PCR-00: 1111111111111111111111111111111111111111111111111111111111111111\n" > /tmp/ooattest-test/tampered.txt
	@./$(BIN) --verify /tmp/ooattest-test/tampered.txt > /tmp/ooattest-test/verdict.out || true
	@grep -q "TAMPERED" /tmp/ooattest-test/verdict.out && echo "PASS: verify detected drift"
	@echo "=== testing MCP initialize ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "protocolVersion" && echo "PASS: MCP initialize"
	@echo "=== testing MCP tools/list ==="
	@printf '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "attest_status" && echo "PASS: MCP tools/list"
	@echo "=== testing MCP tools/call attest_status ==="
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"attest_status","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q 'device' && echo "PASS: MCP attest_status"
	@echo "=== testing MCP tools/call attest_hash_pcr ==="
	@printf '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"attest_hash_pcr","arguments":{"digest":"3a4f128bcde90123456789abcdef0123456789abcdef0123456789abcdef0123"}}}\n' | ./$(BIN) --mcp | grep -q 'sha256' && echo "PASS: MCP attest_hash_pcr"
	@echo "=== testing MCP tools/call attest_verify ==="
	@printf '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"attest_verify","arguments":{"index":0,"expected_digest":"3a4f128bcde90123456789abcdef0123456789abcdef0123456789abcdef0123"}}}\n' | ./$(BIN) --mcp | grep -q 'trusted.*true' && echo "PASS: MCP attest_verify"
	@rm -rf /tmp/ooattest-test
	@echo "ALL TESTS PASSED"

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/ooattest
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/ooattest-uninstall
	@echo "installed ooattest and ooattest-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/ooattest $(DESTDIR)$(BINDIR)/ooattest-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/ooattest $(HOME)/.config/ooattest; echo "purged user cache and config"; fi
	@echo "uninstalled ooattest and ooattest-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/ooattest
	@chmod 0755 dist/deb-root/usr/bin/ooattest
	@cp uninstall.sh dist/deb-root/usr/bin/ooattest-uninstall
	@chmod 0755 dist/deb-root/usr/bin/ooattest-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/ooattest_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/ooattest_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/ooattest-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/ooattest.spec > ~/rpmbuild/SPECS/ooattest.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/ooattest.spec
	@cp ~/rpmbuild/RPMS/x86_64/ooattest-$(VERSION)*.rpm dist/
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/ooattest
	@chmod 0755 dist/arch-pkg/usr/bin/ooattest
	@cp uninstall.sh dist/arch-pkg/usr/bin/ooattest-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/ooattest-uninstall
	@printf "pkgname = ooattest\npkgbase = ooattest\npkgver = $(VERSION)-1\npkgdesc = Attests system state and measured boot hashes using TPM2 hardware security chips.\nurl = https://github.com/openOODA-tools/ooattest\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = ooattest\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/ooattest-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/ooattest-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cd dist && sha256sum ooattest* > checksums.txt 2>/dev/null || true
	@echo "built all packages and dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
