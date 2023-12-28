# NixOs Configuration files

To apply a configuration for a particular host:
```shell
sudo nixos-rebuild switch --flake /etc/nixos/#meshify
```
Replace `meshify` with the desired host, found in `hosts`.
