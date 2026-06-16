# telnet

The `telnet` client from [GNU inetutils](https://www.gnu.org/software/inetutils/) —
the classic TELNET protocol client for interactive connections and quick TCP
port probing. A single self-contained binary, built natively for Linux, macOS,
and Windows.

[![CI](https://github.com/unpins/telnet/actions/workflows/telnet.yml/badge.svg)](https://github.com/unpins/telnet/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install telnet`.

## Usage

Run the `telnet` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin telnet example.com 80      # connect to host:port
unpin telnet                     # interactive, then `open host port`
```

To install it onto your PATH:

```bash
unpin install telnet
```

## Man pages

`telnet.1` is embedded in the binary — read it with `unpin man telnet`.

## Build locally

```bash
nix build github:unpins/telnet
./result/bin/telnet --version
```

Or run directly:

```bash
nix run github:unpins/telnet -- --version
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/telnet/releases) page has standalone binaries for manual download.

## Build notes

- **Platforms:** Linux, macOS, Windows. There is no clean mingw route — telnet
  is BSD-sockets + termios and inetutils' build is Unix-only — so Windows goes
  through [Cosmopolitan](https://github.com/jart/cosmopolitan), whose libc
  supplies the POSIX layer; the result is a single `telnet.exe` (a PE32+, apelinked from the cosmocc APE) that
  links no companion DLLs.
- **One tool:** inetutils builds about thirty programs (ftp, rsh, the `*d`
  servers, …); Debian splits the TELNET client into its own `inetutils-telnet`
  package, and that one binary is all we ship — built with
  `--disable-clients --disable-servers --enable-telnet` so only the TELNET client
  compiles.
- **Terminfo:** telnet links ncurses for line-mode terminal handling; we swap in
  an embedded-fallback ncurses so the binary carries its own terminal
  capabilities and stays runnable anywhere (no `/nix/store` terminfo reference).
- **Cosmo build notes:** Cosmopolitan's libc is missing a few BSD bits inetutils
  expects, all patched for that target only — it ships no `<arpa/telnet.h>`
  (vendored here as the standard BSD header) or `<arpa/tftp.h>`; it has no
  `if_nameindex` family (a struct/prototype shim lets `libinetutils` compile);
  and it expresses baud rates and the terminal-flush ioctl differently
  (`DECODE_BAUD` is disabled and `TCFLSH` is replaced with POSIX `tcflush`). The
  build is also trimmed to telnet's own subdirectories so the ftp/ping/talk/…
  code (which pulls in yet more Linux-only headers) never compiles.
