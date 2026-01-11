{port ? 8080}: {lib, ...}: let
  global_const = import ../global_constants.nix;
in {
  # Define a new option
  services.searx = {
    enable = true;
    environmentFile = "/home/${global_const.username}/.searxng.env";
    redisCreateLocally = true;

    settings = {
      server = {
        bind_address = "0.0.0.0";
        inherit port;
        limiter = true;
        public_instance = false;
        image_proxy = true;
      };
      general = {
        debug = true;
        instance_name = "MGW SearXNG Instance";
        donation_url = false;
        contact_url = false;
        privacypolicy_url = false;
        enable_metrics = false;
      };
      limiterSettings = {
        real_ip = {
          x_for = 1;
          ipv4_prefix = 32;
          ipv6_prefix = 56;
        };

        botdetection = {
          ip_limit = {
            filter_link_local = true;
            link_token = true;
          };
        };
      };
      outgoing = {
        request_timeout = 5.0;
        max_request_timeout = 15.0;
        pool_connections = 100;
        pool_maxsize = 15;
        enable_http2 = true;
      };
      # UWSGI configuration
      runInUwsgi = true;

      uwsgiConfig = {
        socket = "/run/searx/searx.sock";
        http = ":8888";
        chmod-socket = "660";
      };

      engines = lib.mapAttrsToList (name: value: {inherit name;} // value) {
        "duckduckgo".disabled = false;
        "brave".disabled = true;
        "bing".disabled = false;
        "mojeek".disabled = false;
        "mwmbl".disabled = false;
        "mwmbl".weight = 0.4;
        "qwant".disabled = true;
        "crowdview".disabled = false;
        "crowdview".weight = 0.5;
        "curlie".disabled = false;
        "ddg definitions".disabled = false;
        "ddg definitions".weight = 2;
        "wikibooks".disabled = false;
        "wikidata".disabled = false;
        "wikiquote".disabled = false;
        "wikisource".disabled = false;
        "wikispecies".disabled = false;
        "wikispecies".weight = 0.5;
        "wikiversity".disabled = false;
        "wikiversity".weight = 0.5;
        "wikivoyage".disabled = false;
        "wikivoyage".weight = 0.5;
        "currency".disabled = false;
        "dictzone".disabled = false;
        "lingva".disabled = false;
        "bing images".disabled = false;
        "brave.images".disabled = false;
        "duckduckgo images".disabled = false;
        "google images".disabled = false;
        "qwant images".disabled = false;
        "1x".disabled = false;
        "artic".disabled = false;
        "deviantart".disabled = false;
        "flickr".disabled = false;
        "imgur".disabled = false;
        "library of congress".disabled = false;
        "material icons".disabled = false;
        "material icons".weight = 0.2;
        "openverse".disabled = false;
        "pinterest".disabled = false;
        "svgrepo".disabled = false;
        "unsplash".disabled = false;
        "wallhaven".disabled = false;
        "wikicommons.images".disabled = false;
        "yacy images".disabled = false;
        "bing videos".disabled = false;
        "brave.videos".disabled = false;
        "duckduckgo videos".disabled = false;
        "google videos".disabled = false;
        "qwant videos".disabled = false;
        "dailymotion".disabled = false;
        "google play movies".disabled = false;
        "invidious".disabled = false;
        "odysee".disabled = false;
        "peertube".disabled = false;
        "piped".disabled = false;
        "rumble".disabled = false;
        "sepiasearch".disabled = false;
        "vimeo".disabled = false;
        "youtube".disabled = false;
        "brave.news".disabled = false;
        "google news".disabled = false;
      };
    };
  };
  networking.firewall.allowedTCPPorts = [
    port
  ];
}
