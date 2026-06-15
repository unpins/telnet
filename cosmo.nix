# telnet (GNU inetutils client) for Windows-x86_64 via cosmoStaticCross — a
# single APE `telnet.exe`. There is no clean mingw route: telnet is BSD sockets
# + termios and inetutils' autotools harness is Unix-only, both of which
# mingw-w64 lacks. Cosmopolitan's libc provides the POSIX layer configure probes
# for (sockets, termios, the system headers), so the cosmo cross builds it; the
# cosmo stdenv apelinks $out/bin/telnet (ELF → telnet.exe) in fixupPhase.
#
# cosmo's libc is missing a handful of BSD bits inetutils expects; every patch
# below is applied for the cosmo target only and is documented inline. See
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
  # (b) we trim `doc` out of SUBDIRS (below), so the `info` output would
  # be empty and fail. One output keeps telnet.1 in $out/share/man for
  # the wrapper to embed. Drop the apparmor postInstall too.
  outputs = [ "out" ];
  postInstall = "";
  # libinetutils/if_index.c provides if_nametoindex()/if_nameindex()
  # when the platform lacks them (configure → HAVE_STRUCT_IF_NAMEINDEX
  # unset on cosmo, whose <net/if.h> has no if_nameindex family). Its
  # replacement code uses `struct if_nameindex`, but only libinetutils.h
  # declares that struct (under the same guard) and if_index.c never
  # includes it — so on glibc/musl it compiles thanks to <net/if.h>, but
  # on cosmo the type is undefined. Inject the same struct definition.
  # (telnet itself doesn't reference the family — only ifconfig does —
  # so this is purely to let libinetutils.a compile.)
  postPatch = (old.postPatch or "") + ''
            # inetutils builds ALL its support libraries + program dirs
            # regardless of --disable-clients/--disable-servers (those only gate
            # which bin_PROGRAMS install). libicmp/libls + the ftp/talk/ping/…
            # dirs drag in more BSD headers cosmo lacks (netinet/in_systm.h, …)
            # for code telnet never links. Trim SUBDIRS to exactly telnet's
            # closure: gnulib `lib`, libinetutils, libtelnet, the telnet client,
            # and `man` (which installs the prebuilt telnet.1, no help2man run).
            sed -i '/^SUBDIRS = lib/,/tests/c\SUBDIRS = lib libinetutils libtelnet telnet man' Makefile.in

            substituteInPlace libinetutils/if_index.c \
              --replace-fail '#include <net/if.h>' '#include <net/if.h>
            #ifndef HAVE_STRUCT_IF_NAMEINDEX
            struct if_nameindex { char *if_name; int if_index; };
            unsigned int if_nametoindex (const char *ifname);
            struct if_nameindex *if_nameindex (void);
            void if_freenameindex (struct if_nameindex *ptr);
            #endif'

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
            # telnet/sys_bsd.c decides "encoded (4.2BSD) vs numeric (4.4BSD)"
            # baud rates via `#if B4800 != 4800 → #define DECODE_BAUD`, which
            # then builds a static termspeeds[] table out of B0/B50/.../B230400.
            # On cosmo those B* are `extern const uint32_t` (runtime values, not
            # macros), so the preprocessor reads B4800 as 0 (→ DECODE_BAUD on)
            # and the table fails to compile (non-constant static initializers /
            # undeclared at file scope). Terminal line speed is cosmetic for a
            # networked client on Windows — disable DECODE_BAUD on cosmo so
            # TerminalSpeeds just passes cfgetospeed()/cfgetispeed() through.
            substituteInPlace telnet/sys_bsd.c \
              --replace-fail '#if B4800 != 4800' '#if B4800 != 4800 && !defined __COSMOPOLITAN__'

            # TerminalFlushOutput falls back to the Linux `TCFLSH` ioctl when
            # <sys/ioctl.h> has no TIOCFLUSH. cosmo has neither ioctl number but
            # does provide the POSIX tcflush()/TCIOFLUSH — use it instead.
            substituteInPlace telnet/sys_bsd.c \
              --replace-fail 'ioctl (fileno (stdout), TCFLSH, &flags);' \
                             'tcflush (fileno (stdout), TCIOFLUSH); (void) flags;'

            mkdir -p libinetutils/arpa
            cat > libinetutils/arpa/tftp.h <<'TFTP_H'
            #ifndef _ARPA_TFTP_H
            #define _ARPA_TFTP_H 1
            #define SEGSIZE 512
            #define RRQ 01
            #define WRQ 02
            #define DATA 03
            #define ACK 04
            #define ERROR 05
            #define OACK 06
            struct tftphdr {
              short th_opcode;
              union {
                unsigned short tu_block;
                short tu_code;
                char tu_stuff[1];
              } th_u;
              char th_data[1];
            };
            #define th_block th_u.tu_block
            #define th_code th_u.tu_code
            #define th_stuff th_u.tu_stuff
            #define th_msg th_data
            #define EUNDEF 0
            #define ENOTFOUND 1
            #define EACCESS 2
            #define ENOSPACE 3
            #define EBADOP 4
            #define EBADID 5
            #define EEXISTS 6
            #define ENOUSER 7
            #define EOPTNEG 8
            #endif
            TFTP_H
          '';
})
