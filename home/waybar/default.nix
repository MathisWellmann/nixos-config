{pkgs, ...}: {
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";

        modules-left = [
          # "hyprland/mode"
          "hyprland/workspaces"
          "custom/arrow9"
          "hyprland/window"
        ];

        modules-right = [
          "custom/brightness"
          "custom/arrow8"
          "idle_inhibitor"
          "custom/arrow7"
          "pulseaudio"
          "custom/arrow6"
          "network"
          "custom/arrow5"
          "memory"
          "custom/arrow4"
          "cpu"
          "custom/arrow3"
          "temperature"
          "custom/arrow2"
          "clock#date"
          "custom/arrow1"
          "clock#time"
        ];

        battery = {
          interval = 10;
          states = {
            warning = 30;
            critical = 15;
          };
          format-time = "{H}:{M:02}";
          format = "{icon} {capacity}% ({time})";
          format-charging = " {capacity}% ({time})";
          format-charging-full = " {capacity}%";
          format-full = "{icon} {capacity}%";
          format-alt = "{icon} {power}W";
          format-icons = [
            " "
            " "
            " "
            " "
            " "
          ];
          tooltip = false;
        };

        "clock#time" = {
          interval = 10;
          format = "{:%H:%M}";
          tooltip = false;
        };

        "clock#date" = {
          interval = 20;
          format = "{:%e %b %Y}";
          tooltip = false;
        };

        cpu = {
          interval = 5;
          tooltip = false;
          format = " {usage}%";
          format-alt = " {load}";
          states = {
            warning = 70;
            critical = 90;
          };
        };

        "hyprland/language" = {
          format = " {}";
          min-length = 5;
          on-click = "${pkgs.hyprland}/bin/hyprlandmsg 'input * xkb_switch_layout next'";
          tooltip = false;
        };

        memory = {
          interval = 5;
          format = " {used:0.1f}G/{total:0.1f}G";
          states = {
            warning = 70;
            critical = 90;
          };
          tooltip = false;
        };

        network = {
          interval = 5;
          format-wifi = " {essid} ({signalStrength}%)";
          format-ethernet = " {ifname}";
          format-disconnected = "No connection";
          format-alt = " {ipaddr}/{cidr}";
          tooltip = false;
        };

        "hyprland/mode" = {
          format = "{}";
          tooltip = false;
        };

        "hyprland/window" = {
          format = "{}";
          max-length = 30;
          tooltip = false;
        };

        "hyprland/workspaces" = {
          disable-scroll-wraparound = true;
          smooth-scrolling-threshold = 4;
          enable-bar-scroll = true;
          format = "{icon}";
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-bluetooth = "{icon} {volume}%";
          format-muted = "";
          format-icons = {
            headphone = " ";
            hands-free = "";
            headset = "";
            phone = " ";
            portable = " ";
            car = " ";
            default = [" " " "];
          };
          scroll-step = 1;
          on-click = "${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
          tooltip = false;
        };

        temperature = {
          critical-threshold = 90;
          interval = 5;
          format = "{icon} {temperatureC}°";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
          tooltip = false;
        };

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = " ";
            deactivated = " ";
          };
          tooltip = false;
        };

        tray = {
          icon-size = 18;
        };

        "custom/arrow1" = {
          format = "";
          tooltip = false;
        };

        "custom/arrow2" = {
          format = "";
          tooltip = false;
        };

        "custom/arrow3" = {
          format = "";
          tooltip = false;
        };

        "custom/arrow4" = {
          format = "";
          tooltip = false;
        };

        "custom/arrow5" = {
          format = "";
          tooltip = false;
        };

        "custom/arrow6" = {
          format = "";
          tooltip = false;
        };

        "custom/arrow7" = {
          format = "";
          tooltip = false;
        };

        "custom/arrow8" = {
          format = "";
          tooltip = false;
        };

        "custom/arrow9" = {
          format = "";
          tooltip = false;
        };
      };
    };

    style = ./waybar.css;
  };
}
