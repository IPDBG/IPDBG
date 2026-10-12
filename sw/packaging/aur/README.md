# Arch Linux packages (AUR)

`PKGBUILD` builds the host software for Arch Linux from the source archive
of the tag: `ipdbg-ioview`, `ipdbg-uartbridge`, `libipdbg` (libraries,
headers and pkg-config files, as usual on Arch), `python-ipdbg` and
`octave-ipdbg`.

Without the AUR, from a checkout:

```sh
cd sw/packaging/aur
makepkg -si
```

`ci-arch.sh` builds and checks the packages in an Arch container (job
*linux-packages*, see [`../README.md`](../README.md)) and writes the
`.SRCINFO` that the AUR needs.

## Release

1. Set `pkgver` (and `pkgrel=1`) in `PKGBUILD` and the checksum of the
   source archive:
   `curl -sL https://github.com/IPDBG/IPDBG/archive/refs/tags/vVERSION.tar.gz | sha256sum`.
2. Take `.SRCINFO` from the artifact of the job *linux-packages (arch)*, or
   run `makepkg --printsrcinfo > .SRCINFO` on Arch.
3. Commit both to the AUR repository and push:

   ```sh
   git clone ssh://aur@aur.archlinux.org/ipdbg.git aur-ipdbg
   cp PKGBUILD .SRCINFO aur-ipdbg/
   cd aur-ipdbg && git commit -am "ipdbg VERSION" && git push
   ```

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
