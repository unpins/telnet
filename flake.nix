{
  description = "telnet (GNU inetutils) as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # The `telnet` client from GNU inetutils 2.x. inetutils builds ~30 programs
  # (ftp, rsh, ping, ifconfig, the *d servers, …); Debian splits the telnet
  # client into its own `inetutils-telnet` package and that's all we ship here.
  # `--disable-clients --disable-servers --enable-telnet` builds the one binary
  # we want; the leftover libtool/man bits for the other tools never get built.
  #
  # telnet links ncurses, and gets nothing from it. Its one termcap call sits
  # behind HAVE_TGETENT, which `IU_LIB_TERMCAP` (am/libcurses.m4) defines only
  # in the branch it takes when ncurses is NOT found -- finding ncurses sets
  # LIBTERMCAP and leaves the macro undefined. So the call is compiled out here
  # exactly as it is in Debian's build: no terminal database is read and none is
  # needed. Measured: the else-branch probes never appear in our build log, and
  # the binary has no ncurses/terminfo/xterm strings at all.
  # Windows goes through Cosmopolitan (mingw can't do telnet's BSD sockets +
  # termios + Unix-only autotools); the recipe and its cosmo-only patches live
  # in the ./cosmo.nix sidecar.
  outputs = { self, unpins-lib }:
    let
      lib = unpins-lib.lib;
      # Build only the telnet client out of inetutils' ~30 programs.
      telnetOnly = [ "--disable-clients" "--disable-servers" "--enable-telnet" ];
    in
    lib.mkStandaloneFlake {
      inherit self;
      name = "telnet";
      # telnet takes a hostname; on a host with no reachable resolver (Android,
      # a barebones container) musl's getaddrinfo just fails. Opt into the
      # catalog's DNS fallback, which stays dormant until the user configures
      # one -- same as curl/links/rsync/whois.
      dnsFallback = true;

      # Build via the unpin-llvm engine + emit a bitcode multicall module. The
      # engine compiles every Linux arch with `clang -target` (no nixpkgs gcc
      # cross toolchain, no qemu) and self-folds darwin the same way; Windows
      # stays on cosmo below (engine covers Linux + darwin only).
      engine = "unpin-llvm";
      multicall = {
        inferLinkInputs = true;
        programs = [{ name = "telnet"; }];
      };
      # Upstream nixpkgs attr is `inetutils` (this build keeps only `telnet`);
      # name it so the engine's stdenv override targets the right attr.
      pkgsAttr = "inetutils";
      binName = "telnet";
      smoke = [ "--version" ];
      smokePattern = "telnet \\(GNU inetutils\\)";
      build = pkgs:
        pkgs.pkgsStatic.inetutils.overrideAttrs (old: {
          configureFlags = (old.configureFlags or [ ]) ++ telnetOnly;
          # nixpkgs inetutils is multi-output ("out"/"apparmor"/"info"/"man")
          # and its postInstall builds a `ping` AppArmor profile via
          # `apparmorRulesFromClosure` (an exportReferencesGraph closure drv).
          # Under the engine (which forces __structuredAttrs and appends a
          # `module` output), that exportReferencesGraph path serialises a null
          # → "[json.exception.type_error.302] type must be string, but is null"
          # at instantiation. We `--disable-clients --disable-servers`, so ping
          # (and every other program but telnet) is never built — the apparmor
          # output and its postInstall are dead weight. Collapse to a single
          # `out` (engine still appends `module`) and drop the postInstall.
          outputs = [ "out" ];
          postInstall = "";
        });
      # Windows via cosmocc — the recipe + all its cosmo-only patches live in
      # the sidecar (see ./cosmo.nix); `telnetOnly` is shared with the native
      # build above and threaded in.
      windowsBuild = import ./cosmo.nix { inherit unpins-lib telnetOnly; };
    };
}
