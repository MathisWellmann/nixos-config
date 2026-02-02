# NixOs Configuration files

To apply a configuration for a particular host, e.g `meshify`:
```shell
sudo nixos-rebuild switch --flake .#meshify
```
Replace `meshify` with the desired host, found in `hosts`.

I recommend using [`nh`] to switch the configuration using:
```shell
nh os switch .
```

[`nh`]: https://github.com/nix-community/nh

## Updating
To update all flake inputs and pull in the newest packages:
```shell
nix flake update
```

See the metadata and the current flake inputs:
```shell
nix flake metadata .
```

To update the flake input `nixpkgs` specifically:
```shell
nix flake lock --update-input nixpkgs
```

Then update the system, eg for the `meshify` host configuration:
```
sudo nixos-rebuild switch --flake .#meshify --upgrade-all
```

## Cleaning system store manually
```shell
nix-store --gc
```

Use `nh` to keep only the last 5 system revisions in the boot menu:
```shell
nh clean all --keep 5
```

# Tips:
When getting something like this:
```shell
  error: cached failure of attribute 'nixosConfigurations.poweredge.config.system.build.toplevel'
```
Then you can disable the eval-cache temporarily by running with `--option eval-cache false`.

Check out which package depends on another (for example an insecure one):
```shell
nix why-depends /run/current-system $(nix-build '<nixpkgs>' -A electron_35 --no-out-link)
```
