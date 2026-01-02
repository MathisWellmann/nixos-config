{
  self,
  pkgs,
  ...
}:
with builtins; let
  systems = attrNames self.nixosConfigurations;
  systems_string = concatStringsSep " " systems;

  # Get the primary interface of a host as specified by the `defaultGateway`, if any.
  getPrimaryInterface = host: self
    .nixosConfigurations
    .${host}
    .config
    .networking
    .defaultGateway
    .interface or "unknown";

  # Get the MAC address of a host interface, if any.
  getMacAddress = host:
  let
    ifs = self
      .nixosConfigurations
      .${host}
      .config
      .networking
      .interfaces;
    prim = getPrimaryInterface host;
    macAddress = if hasAttr prim ifs
      then (
        if (ifs.${prim}.macAddress != null)
        then ifs.${prim}.macAddress
        else "no-mac"
      )
      else "invalid-interface";
  in 
    macAddress;

  # Get the mac address of each systems primary NIC.
  macs = map (host: "${toString (getMacAddress host)}") systems;
  macs_string = concatStringsSep " " macs;
in
  pkgs.writeShellScriptBin "wake_on_lan" ''
    echo "systems: ${systems_string}"
    echo "macs: ${macs_string}"

    IFS=' ' read -a arr_systems <<< "${systems_string}"
    IFS=' ' read -a arr_macs <<< "${macs_string}"

    echo "Checking host reachability."
    offline_systems=()
    for i in ''${!arr_systems[@]}; do
      system="''${arr_systems[$i]}"
      mac="''${arr_macs[$i]}"
      echo "Pinging $system @ $mac"

      # Try to ping the system once with 1-second timeout
      ping_output=$(ping -c 1 -w 1 "$system" 2>/dev/null)
      if [ $? -eq 0 ]; then
        # Extract latency in ms from ping output
        latency=$(echo "$ping_output" | grep -oP "time=\K[\d.]+" )
        echo "------> $system is reachable in $latency ms"
      else
        echo "$system is not reachable"
        offline_systems+=("$system=$i")
      fi
    done
    CHOICE=$(${pkgs.gum}/bin/gum choose --label-delimiter '=' --header "Select Host to send WakeOnLan magic packet to:" ''${offline_systems[@]})

    if [ -z "$CHOICE" ]; then
      echo "No host selected"
      exit 1
    fi

    host=''${arr_systems[$CHOICE]}
    mac=''${arr_macs[$CHOICE]}

    ${pkgs.gum}/bin/gum confirm "Do you want to send magic WakeOnLan packet to $host @ $mac ?" && {
      ${pkgs.wakeonlan}/bin/wakeonlan $mac

      # wait until the host is reachable
      timeout="''${2:-300}"  # Default: 5 minutes
      count=0

      echo "Waiting for $host to respond to ping (timeout: $timeout seconds)..."

      while ! ping -c 1 -W 1 "$host" &>/dev/null; do
        count=$((count + 1))
  
        if [ $count -ge $timeout ]; then
          echo "❌ Timeout! Host $host did not respond within $timeout seconds."
          exit 1
        fi

        # Optional: show progress every 10 seconds
        if [ $((count % 10)) -eq 0 ]; then
          echo "Still waiting... ($count seconds elapsed)"
        fi

        sleep 1
      done

      echo "✅ Host $host is reachable!"
    }

  ''
