# Amnesic I2P desktop VM: Java I2P router plus a Firefox set up as in
# https://i2p.net/en/docs/guides/gettingstarted/
#
# Build and run with `nix-build vms/i2p.nix; result/bin/run-i2p-vm`
#
# The root filesystem is a tmpfs: nothing survives a shutdown, and every boot
# starts a fresh router, so expect 3-10 minutes of reseeding before .i2p
# sites load. Watch progress in the router console (Firefox home page).
let
  pkgs = import <nixpkgs> {};
  console = "http://127.0.0.1:7657";

  i2p_vm = {
    imports = [
      ./desktop.nix
      ./leak-guard.nix
    ];

    networking.hostName = "i2p";
    leakGuard.allowedUser = "i2p";

    services.i2p.enable = true;
    # The router falls back to JVM system properties for keys missing from
    # router.config. Marking the welcome wizard as done stops it (and its
    # M-Lab bandwidth test) from coming back on every boot.
    systemd.services.i2p.environment.JAVA_TOOL_OPTIONS = "-Drouterconsole.welcomeWizardComplete=true";

    programs.firefox = {
      enable = true;
      policies = {
        Proxy = {
          Mode = "manual";
          HTTPProxy = "127.0.0.1:4444";
          UseHTTPProxyForAllProtocols = true;
          Locked = true;
        };
        Homepage = {
          URL = "${console}/home";
          StartPage = "homepage";
          Locked = true;
        };
        DNSOverHTTPS = {
          Enabled = false;
          Locked = true;
        };
        CaptivePortal = false;
        NetworkPrediction = false;
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableFirefoxAccounts = true;
        DontCheckDefaultBrowser = true;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        SearchSuggestEnabled = false;
        DisplayBookmarksToolbar = "always";
        # Starting points from the guide.
        ManagedBookmarks = [
          {toplevel_name = "I2P";}
          {
            name = "Router console";
            url = "${console}/home";
          }
          {
            name = "I2PSnark";
            url = "${console}/i2psnark/";
          }
          {
            name = "SusiMail";
            url = "${console}/susimail/";
          }
          {
            name = "I2P project";
            url = "http://i2p-projekt.i2p/";
          }
          {
            name = "I2P forum";
            url = "http://i2pforum.i2p/";
          }
          {
            name = "stats.i2p";
            url = "http://stats.i2p/";
          }
          {
            name = "notbob.i2p (site uptime)";
            url = "http://notbob.i2p/";
          }
        ];
      };
      preferences = {
        # about:config changes from the guide.
        "media.peerconnection.ice.proxy_only" = true;
        "keyword.enabled" = false;
        "browser.fixup.domainsuffixwhitelist.i2p" = true;
        # What the guide's "I2P in Private Browsing" extension turns on.
        "privacy.resistFingerprinting" = true;
        "privacy.resistFingerprinting.letterboxing" = true;
        "privacy.firstparty.isolate" = true;
        # WebRTC is the classic proxy bypass and nothing here needs it.
        "media.peerconnection.enabled" = false;
        # .i2p sites are plain HTTP (I2P encrypts end to end). HTTPS-First
        # would try TLS through the proxy first on every visit.
        "dom.security.https_first" = false;
        "dom.security.https_first_schemeless" = false;
        # These background requests would go out through the I2P outproxy.
        "browser.safebrowsing.malware.enabled" = false;
        "browser.safebrowsing.phishing.enabled" = false;
        "browser.safebrowsing.downloads.enabled" = false;
        "network.connectivity-service.enabled" = false;
        "geo.enabled" = false;
      };
    };

    virtualisation.vmVariant.virtualisation = {
      # Root on tmpfs instead of a qcow2 disk image.
      diskImage = null;
      # The JVM, Firefox and the tmpfs root all live in RAM.
      memorySize = 4096;
    };
  };
  vms = pkgs.nixos [
    i2p_vm
  ];
in
  vms.config.system.build.vm
