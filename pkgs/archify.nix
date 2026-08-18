{
  pkgs,
  lib,
  ...
}: let
  src = pkgs.fetchzip {
    url = "https://registry.npmjs.org/@tt-a1i/archify-dsh/-/archify-dsh-0.1.0.tgz";
    hash = "sha256-QWwjlh5H2l8DJYw24p0K6SaZ0OJKVI5oYsu/H/IIG5g=";
  };
in
  pkgs.writeShellScriptBin "archify" ''
    exec ${pkgs.nodejs}/bin/node ${src}/skills/archify/bin/archify.mjs "$@"
  ''
