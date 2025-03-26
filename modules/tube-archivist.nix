# Auto-generated using compose2nix v0.3.1.
{
  pkgs,
  lib,
  ...
}: {
  # Runtime
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
    defaultNetwork.settings = {
      # Required for container networking to be able to use names.
      dns_enabled = true;
    };
  };

  # Enable container name DNS for non-default Podman networks.
  # https://github.com/NixOS/nixpkgs/issues/226365
  networking.firewall.interfaces."podman+".allowedUDPPorts = [53];

  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."archivist-es" = {
    image = "bbilly1/tubearchivist-es";
    environment = {
      "ELASTIC_PASSWORD" = "verysecret";
      "ES_JAVA_OPTS" = "-Xms1g -Xmx1g";
      "discovery.type" = "single-node";
      "path.repo" = "/usr/share/elasticsearch/data/snapshot";
      "xpack.security.enabled" = "true";
    };
    volumes = [
      "tubearchivist_es:/usr/share/elasticsearch/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=archivist-es"
      "--network=tubearchivist_default"
    ];
  };
  systemd.services."podman-archivist-es" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-tubearchivist_default.service"
      "podman-volume-tubearchivist_es.service"
    ];
    requires = [
      "podman-network-tubearchivist_default.service"
      "podman-volume-tubearchivist_es.service"
    ];
    partOf = [
      "podman-compose-tubearchivist-root.target"
    ];
    wantedBy = [
      "podman-compose-tubearchivist-root.target"
    ];
  };
  virtualisation.oci-containers.containers."archivist-redis" = {
    image = "redis";
    volumes = [
      "tubearchivist_redis:/data:rw"
    ];
    dependsOn = [
      "archivist-es"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=archivist-redis"
      "--network=tubearchivist_default"
    ];
  };
  systemd.services."podman-archivist-redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-tubearchivist_default.service"
      "podman-volume-tubearchivist_redis.service"
    ];
    requires = [
      "podman-network-tubearchivist_default.service"
      "podman-volume-tubearchivist_redis.service"
    ];
    partOf = [
      "podman-compose-tubearchivist-root.target"
    ];
    wantedBy = [
      "podman-compose-tubearchivist-root.target"
    ];
  };
  virtualisation.oci-containers.containers."tubearchivist" = {
    image = "bbilly1/tubearchivist";
    environment = {
      "ELASTIC_PASSWORD" = "verysecret";
      "ES_URL" = "http://archivist-es:9200";
      "HOST_GID" = "1000";
      "HOST_UID" = "1000";
      "REDIS_CON" = "redis://archivist-redis:6379";
      "TA_HOST" = "http://tubearchivist.local";
      "TA_PASSWORD" = "verysecret";
      "TA_USERNAME" = "tubearchivist";
      "TZ" = "America/New_York";
    };
    volumes = [
      "tubearchivist_cache:/cache:rw"
      "tubearchivist_media:/youtube:rw"
    ];
    ports = [
      "8000:8000/tcp"
    ];
    dependsOn = [
      "archivist-es"
      "archivist-redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"curl\", \"-f\", \"http://localhost:8000/health\"]"
      "--health-interval=2m0s"
      "--health-retries=3"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--network-alias=tubearchivist"
      "--network=tubearchivist_default"
    ];
  };
  systemd.services."podman-tubearchivist" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-tubearchivist_default.service"
      "podman-volume-tubearchivist_cache.service"
      "podman-volume-tubearchivist_media.service"
    ];
    requires = [
      "podman-network-tubearchivist_default.service"
      "podman-volume-tubearchivist_cache.service"
      "podman-volume-tubearchivist_media.service"
    ];
    partOf = [
      "podman-compose-tubearchivist-root.target"
    ];
    wantedBy = [
      "podman-compose-tubearchivist-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-tubearchivist_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f tubearchivist_default";
    };
    script = ''
      podman network inspect tubearchivist_default || podman network create tubearchivist_default
    '';
    partOf = ["podman-compose-tubearchivist-root.target"];
    wantedBy = ["podman-compose-tubearchivist-root.target"];
  };

  # Volumes
  systemd.services."podman-volume-tubearchivist_cache" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect tubearchivist_cache || podman volume create tubearchivist_cache
    '';
    partOf = ["podman-compose-tubearchivist-root.target"];
    wantedBy = ["podman-compose-tubearchivist-root.target"];
  };
  systemd.services."podman-volume-tubearchivist_es" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect tubearchivist_es || podman volume create tubearchivist_es
    '';
    partOf = ["podman-compose-tubearchivist-root.target"];
    wantedBy = ["podman-compose-tubearchivist-root.target"];
  };
  systemd.services."podman-volume-tubearchivist_media" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect tubearchivist_media || podman volume create tubearchivist_media
    '';
    partOf = ["podman-compose-tubearchivist-root.target"];
    wantedBy = ["podman-compose-tubearchivist-root.target"];
  };
  systemd.services."podman-volume-tubearchivist_redis" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect tubearchivist_redis || podman volume create tubearchivist_redis
    '';
    partOf = ["podman-compose-tubearchivist-root.target"];
    wantedBy = ["podman-compose-tubearchivist-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-tubearchivist-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
