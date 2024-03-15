# NixOs Configuration files

To apply a configuration for a particular host, e.g `meshify`:
```shell
sudo nixos-rebuild switch --flake .#meshify
```
Replace `meshify` with the desired host, found in `hosts`.

## Using modules
If you want to use for example the `monero.nix` module in your NixOs base system,
then copy `modules/monero.nix` into `/etc/nixos/modules/monero.nix` (make sure to create the `modules` directory in `/etc/nixos`).
Then modify your `/etc/nixos/configuration.nix` file to include the module as such:
```
imports = [
  # Include the results of the hardware scan.
  ./hardware-configuration.nix
  ./../../modules/monero.nix
];
```
Now rebuild as such:
```shell
sudo nixos-rebuild switch
```

## Updating
See the metadata and the current flake inputs:
```shell
nix flake metadata .
```
There one can see the `Inputs`.

To update the flake input `nixpkgs`:
```shell
nix flake lock --update-input nixpkgs
```

Then update the system, eg for the `meshify` host configuration:
```
sudo nixos-rebuild switch --flake .#meshify --upgrade-all
```
