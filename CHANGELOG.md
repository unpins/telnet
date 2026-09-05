# Changelog

## [Unreleased]

### Fixed

- On Linux, hostnames now resolve on a machine whose DNS resolver is missing or
  unreachable — Android, or a container with no `/etc/resolv.conf` — once you
  point unpins at a name server. Before, `telnet <host> <port>` gave up with
  `Server lookup failure` and never reached the connection.
