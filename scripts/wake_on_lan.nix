{
  self,
  pkgs,
  ...
}: with builtins; let
  systems = attrNames self.nixosConfigurations;
  systems_string = concatStringsSep " " systems;
  # Lookup the mac address of each systems primary NIC.
  macs = map (host: "test-${host}") systems;
  macs_string = concatStringsSep " " macs;
in
  pkgs.writeShellScriptBin "wake_on_lan" ''
    IFS=' ' read -a arr_systems <<< "${systems_string}"
    IFS=' ' read -a arr_macs <<< "${macs_string}"
    echo "macs: ''${arr_macs[@]}"

    echo "Checking host reachability."
    items=()
    for i in ''${!arr_systems[@]}; do
      system="''${arr_systems[$i]}"
      # Try to ping the system once with 1-second timeout
      ping_output=$(ping -c 1 -w 1 "$system" 2>/dev/null)
      if [ $? -eq 0 ]; then
        # Extract latency in ms from ping output
        latency=$(echo "$ping_output" | grep -oP "time=\K[\d.]+" )
      else
        latency="N/A"
      fi
      item="$system-$latency(ms)=$i"
      echo "$item"
      items+=($item)
    done
    CHOICE=$(${pkgs.gum}/bin/gum choose --label-delimiter '=' --header "Select Host to send WakeOnLan magic packet to:" ''${items[@]})

    if [ -z "$CHOICE" ]; then
      echo "No host selected"
      exit 1
    fi

    selected_host=''${arr_systems[$CHOICE]}

    echo "Sending magic WakeOnLan packet to $selected_host"

    # TODO: get MAC address of host from config.

    # TODO: send magic packet
    # exec ${pkgs.wakeonlan}/bin/wakeonlan $host_mac

    # TODO: wait until the host is reachable
  ''
