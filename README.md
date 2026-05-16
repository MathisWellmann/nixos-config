# NixOS Configuration

## Highlights

- **`modules/github_runner.nix`** — Create a dedicated GitHub runner service for each repository defined in `repos`.

## Applying a Configuration

To switch a host (e.g. `meshify`):

```sh
sudo nixos-rebuild switch --flake .#meshify
```

Replace `meshify` with the desired host name found in the `hosts/` directory.

I recommend using [nh](https://github.com/nix-community/nh) for a simpler workflow:

```sh
nh os switch .
```

## Updating

Update all flake inputs to pull in the newest packages:

```sh
nix flake update
```

View metadata and current flake inputs:

```sh
nix flake metadata .
```

Update a specific input (e.g. `nixpkgs`):

```sh
nix flake lock --update-input nixpkgs
```

Then rebuild the system, e.g. for the `meshify` host:

```sh
sudo nixos-rebuild switch --flake .#meshify --upgrade-all
```

## Cleaning the System Store

Manual garbage collection:

```sh
nix-store --gc
```

Keep only the last 5 system revisions in the boot menu using `nh`:

```sh
nh clean all --keep 5
```

## Tips

**Cached evaluation errors**

If you see something like:

```
error: cached failure of attribute 'nixosConfigurations.poweredge.config.system.build.toplevel'
```

Disable the eval cache temporarily:

```sh
--option eval-cache false
```

**Find which package depends on another** (e.g. an insecure one):

```sh
nix why-depends /run/current-system $(nix-build '<nixpkgs>' -A electron_35 --no-out-link)
```
