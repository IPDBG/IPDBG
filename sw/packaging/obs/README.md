# Linux packages on the openSUSE Build Service

For the maintainers, see also [`../README.md`](../README.md): the files
here build the host software as packages on the
[openSUSE Build Service](https://build.opensuse.org) (OBS) for Fedora,
openSUSE, Debian and Ubuntu, and OBS publishes them as package repositories.
The top-level README tells users how to add the repositories.

| File | Purpose |
|------|---------|
| `_service` | downloads the source archive of the tag from GitHub |
| `ipdbg.spec` | RPM package (Fedora, openSUSE) |
| `ipdbg.dsc`, `debian.*` | Debian package (Debian, Ubuntu); OBS turns `debian.X` into `debian/X` |
| `ci-*.sh` | build and check the packages without OBS, see below |

One source package `ipdbg` builds six packages:

| Package | Contents |
|---------|----------|
| `ipdbg-ioview` | IoView with desktop file and icon |
| `ipdbg-uartbridge` | UartBridge |
| `libipdbg0` | `libipdbg-busaccess.so.0`, `libipdbg-waveformgenerator.so.0` |
| `libipdbg-devel` (Debian: `libipdbg-dev`) | headers, `.so` links, pkg-config files |
| `python3-ipdbg` | Python modules `BusAccess` and `WaveformGenerator` |
| `octave-ipdbg` | Octave modules `BusAccess` and `WaveformGenerator` |

## Testing without OBS

`ci-rpm.sh` and `ci-deb.sh` build the packages from these files in a
container of the distribution, the way OBS does, install them and check
them with `ci-check.sh`. GitHub Actions runs them for Fedora, openSUSE
Tumbleweed and Leap 16, Debian 13 and 12, Ubuntu 24.04 and 26.04 (job
*linux-packages* of the workflow *Host software*) and attaches the packages
to the run. Locally, e.g. with podman:

```sh
podman run --rm -v "$PWD":/src -w /src fedora:latest sw/packaging/obs/ci-rpm.sh out
podman run --rm -v "$PWD":/src -w /src debian:trixie sw/packaging/obs/ci-deb.sh out
```

## Setting up the OBS project

The packages are built in the project `home:ipdbg` (account `ipdbg`).

1. Add the repositories (*Repositories* → *Add from a Distribution*):
   the supported Fedora versions and Rawhide, openSUSE Tumbleweed and
   Leap 16, Debian 13 and 12, Ubuntu 24.04 and the current interim release;
   architectures x86_64 and aarch64.
2. In the project config (*Project Config*), choose between packages that
   provide the same dependency of Octave or wxWidgets; without this, OBS
   reports *unresolvable: have choice for …*:

   ```
   Prefer: texlive-latex texlive-tools texlive-preview gnuplot xpdf-libs
   Prefer: pipewire-jack-audio-connection-kit-libs
   Prefer: libjpeg62-turbo-dev
   Prefer: libsdl2-2.0-0
   ```
3. Create the package `ipdbg` and upload the files, e.g. with
   [osc](https://github.com/openSUSE/osc):

   ```sh
   osc -A https://api.opensuse.org checkout home:ipdbg
   cd home:ipdbg
   osc mkpac ipdbg
   cd ipdbg
   cp <IPDBG>/sw/packaging/obs/{_service,ipdbg.spec,ipdbg.dsc,debian.*} .
   osc add *
   osc commit -m "ipdbg 0.1.1"
   ```

   OBS runs `_service`, downloads the source archive and builds all
   repositories. `osc results` shows the state, `osc buildlog REPO ARCH` the
   log of a build.

## New version

Set the new version in `_service` (URL and file name), `ipdbg.spec`
(`Version`, `%changelog`), `ipdbg.dsc` (`Version`, `DEBTRANSFORM-TAR`) and
`debian.changelog` (new entry at the top), copy the files to the OBS
checkout and commit.

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
