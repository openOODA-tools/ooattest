Name:           ooattest
Version:        0.2.0
Release:        1%{?dist}
Summary:        Attests system state and measured boot hashes using TPM2 hardware security chips.
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/ooattest
Source0:        ooattest-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
ooattest is a sovereign, capability-bounded TPM ATTESTATION utility written
in pure openOODA, featuring zero ambient authority, PCR measurement auditing,
and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/ooattest
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/ooattest-uninstall

%files
/usr/bin/ooattest
/usr/bin/ooattest-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.2.0-1
- Elevate to v0.2.0 with TPM2 PCR measurement auditing and MCP stdio server
