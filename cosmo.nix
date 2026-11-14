# telnet (GNU inetutils client) for Windows-x86_64 via cosmoStaticCross — a
# single PE32+ `telnet.exe`. There is no clean mingw route: telnet is BSD sockets
# + termios and inetutils' autotools harness is Unix-only, both of which
# mingw-w64 lacks. Cosmopolitan's libc provides the POSIX layer configure probes
# for (sockets, termios, the system headers), so the cosmo cross builds it; the
# cosmo stdenv apelinks $out/bin/telnet (ELF → telnet.exe) in fixupPhase.
#
# cosmo's libc is missing a handful of BSD bits inetutils expects; every patch
# and header below is applied for the cosmo target only. See
# docs/platforms/cosmocc.md.
#
# `telnetOnly` (--disable-clients --disable-servers --enable-telnet, shared with
# the native build) is threaded in from flake.nix.
{ unpins-lib, telnetOnly }:
pkgs:
(unpins-lib.lib.cosmoStaticCross pkgs).inetutils.overrideAttrs (old: {
  configureFlags = (old.configureFlags or [ ]) ++ telnetOnly;
  # Collapse to a single output. Stock inetutils is multi-output
  # ("out" "apparmor" "info" "man"); but (a) the `apparmor` profile for
  # `ping` is built via `apparmorRulesFromClosure [ stdenv.cc.libc ]`,
  # whose closure JSON hits a null in the cosmo cross ("type must be
  # string, but is null") — and AppArmor/ping are irrelevant here; and
  # (b) cosmo-subdirs.patch trims `doc` out of SUBDIRS, so the `info`
  # output would be empty and fail. One output keeps telnet.1 in
  # $out/share/man for the wrapper to embed. Drop the apparmor postInstall
  # too.
  outputs = [ "out" ];
  postInstall = "";
  # Each patch says why in its header.
  patches = (old.patches or [ ]) ++ [
    ./cosmo-subdirs.patch
    ./cosmo-if-index.patch
    ./cosmo-sys-bsd.patch
  ];
  postPatch = (old.postPatch or "") + ''
    # cosmo's libc ships neither <arpa/tftp.h> nor <arpa/telnet.h>.
    #
    # <arpa/telnet.h> (TELNET protocol constants) is genuinely needed by
    # libtelnet + the telnet client. We vendor the standard BSD header
    # (byte-identical to glibc's) and drop it on the include path that
    # iu_INCLUDES already adds for every subdir
    # (`-I$(top_srcdir)/lib`), so libtelnet/ and telnet/ both find it.
    mkdir -p lib/arpa
    cp ${./arpa-telnet.h} lib/arpa/telnet.h

    # <arpa/tftp.h> (TFTP packet layout) is only pulled by
    # libinetutils/tftpsubs.c; telnet uses none of it, but the file is
    # compiled into libinetutils.a regardless. tftpsubs.c compiles with
    # `-I.` from libinetutils/, so a local arpa/tftp.h there satisfies
    # the angle-bracket include — drop in the standard BSD header.
    mkdir -p libinetutils/arpa
    cp ${./arpa-tftp.h} libinetutils/arpa/tftp.h
  '';
})
