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
  # telnet links ncurses (termcap, for the line-mode terminal handling). A
  # static ncurses bakes an absolute /nix/store terminfo path, so we swap in the
  # embedded-fallback ncurses (same trick as dash/psmisc/bc) to keep the binary
  # 0-ref and runnable anywhere.
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
      binName = "telnet";
      smoke = [ "--version" ];
      smokePattern = "telnet \\(GNU inetutils\\)";
      build = pkgs:
        (pkgs.pkgsStatic.inetutils.override {
          ncurses = lib.embedFallbackTerminfo pkgs.pkgsStatic.ncurses;
        }).overrideAttrs (old: {
          configureFlags = (old.configureFlags or [ ]) ++ telnetOnly;
        });
      # Windows via cosmocc — the recipe + all its cosmo-only patches live in
      # the sidecar (see ./cosmo.nix); `telnetOnly` is shared with the native
      # build above and threaded in.
      windowsBuild = import ./cosmo.nix { inherit unpins-lib telnetOnly; };
    };
}
