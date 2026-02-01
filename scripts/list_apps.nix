# This script will list all available `apps` in the `flake.nix` and allows choosing which one to run.
{
  self,
  pkgs,
  system,
  ...
}:
with builtins; let
  excludeList = ["default" "list_apps"];
  apps = attrNames self.apps.${system};
  # Get all the `apps` of the flake `self`, without the elements in `excludeList`.
  filtered_apps = filter (name: ! (elem name excludeList)) apps;
  # Convert to String so the script can use it and add a delimiter.
  apps_string = concatStringsSep "\n" filtered_apps;
in {
  script = pkgs.writeShellScriptBin "list-flake-apps" ''
    APPS="${apps_string}"
    CHOICE=$(${pkgs.gum}/bin/gum choose --header "Select App to run" $APPS)
    [[ "$CHOICE" > 0 ]] &&
      eval "nix run .#$CHOICE"
  '';
}
