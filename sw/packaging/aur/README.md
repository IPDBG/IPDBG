# Arch Linux packages

The [openSUSE Build Service](../obs/README.md) builds this `PKGBUILD` and
publishes the packages as a pacman repository; the AUR is not used.

`PKGBUILD` builds the host software for Arch Linux from the source archive
of the tag: `ipdbg-ioview`, `ipdbg-uartbridge`, `libipdbg` (libraries,
headers and pkg-config files, as usual on Arch), `python-ipdbg` and
`octave-ipdbg`.

## Installing

Add the repository and its signing key once:

```sh
repo=https://download.opensuse.org/repositories/home:/ipdbg/Arch
curl -fsSL $repo/x86_64/home_ipdbg_Arch.key | sudo pacman-key --add -
sudo pacman-key --lsign-key "$(curl -fsSL $repo/x86_64/home_ipdbg_Arch.key |
    gpg --show-keys --with-colons | awk -F: '/^fpr/ { print $10; exit }')"
printf '\n[home_ipdbg_Arch]\nServer = %s/$arch\n' $repo | sudo tee -a /etc/pacman.conf
sudo pacman -Sy ipdbg-ioview
```

To build the packages yourself from a checkout:

```sh
cd sw/packaging/aur
makepkg -si
```

`ci-arch.sh` builds and checks the packages in an Arch container (job
*linux-packages*, see [`../README.md`](../README.md)).

## Release

Set `pkgver` (and `pkgrel=1`) in `PKGBUILD` and copy it to the OBS checkout
together with the other files, see [`../obs/README.md`](../obs/README.md#new-version).

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
