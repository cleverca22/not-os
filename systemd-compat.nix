{ lib, ... }:

with lib;

{
  options = {
    # TODO, it just silently ignores all systemd services
    systemd.services = mkOption {
    };
  };
  config = {
  };
}
