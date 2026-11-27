<p align="center">
  <img src="https://raw.githubusercontent.com/pasadizo-net/.github/main/assets/banner.png" alt="Pasadizo, a secret passage for your whole network" width="100%">
</p>

<p align="center">
  <a href="https://github.com/pasadizo-net/hysteria/releases"><img alt="Release" src="https://img.shields.io/github/v/release/pasadizo-net/hysteria?include_prereleases&sort=semver&label=release&color=FFB347"></a>
  <a href="https://github.com/pasadizo-net/hysteria/actions/workflows/pasadizo-ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/pasadizo-net/hysteria/pasadizo-ci.yml?branch=main&label=ci"></a>
  <a href="../LICENSE.md"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-1E1B4B"></a>
  <a href="https://github.com/HyNetworks/hysteria"><img alt="Based on Hysteria" src="https://img.shields.io/badge/based%20on-Hysteria-64748B"></a>
</p>

# Hysteria for Pasadizo

This repository is [Hysteria](https://github.com/HyNetworks/hysteria) 2 with one fix that the Hysteria servers of [Pasadizo](https://github.com/pasadizo-net/pasadizo) gateways need. It is upstream's history up to a release tag (today `app/v2.14.0`), and the fix is one commit on top of it.

**This repository is not affiliated with Hysteria or its authors**, and it is not endorsed by them. Report problems with this build here, never upstream. For everything else (the protocol, the configuration, the documentation) see [upstream](https://github.com/HyNetworks/hysteria) and [v2.hysteria.network](https://v2.hysteria.network/).

## The change

| Change | Files |
| --- | --- |
| The `direct` outbound resolves a UDP destination host name once per UDP session, not once per packet. | `extras/outbounds/ob_direct.go`, `extras/outbounds/ob_direct_udp_test.go` |

Upstream resolves a host name again for every UDP packet and uses the first address of each answer. For a name with several A or AAAA records (`www.google.com`, for example) the packets of one flow then go to different server addresses, and a QUIC handshake sent this way never completes, so HTTP/3 breaks. Clients that send names instead of addresses, such as sing-box or Pasadizo with sniffing or FakeIP, hit this on every HTTP/3 request.

With the fix, the address a name resolves to first is kept for the life of the UDP session and used for every later packet to that name, on any port. A failed resolution is not kept, so the next packet resolves the name again. The cache holds at most 256 names per session. The fix is in the outbound's own resolver, which is used when the server has no `resolver` section. When a `resolver` section (`udp`, `tcp`, `tls` or `https`) has already resolved the name, or an ACL rule has replaced it with an address, the packet carries that address and is handled as upstream handles it.

The commit is written so that it can be offered upstream as it is.

## Releases

Tags look like `app/v2.14.0-pasadizo.1`: upstream's tag, then the release number of this repository. `.github/workflows/pasadizo-release.yml` runs CI, then builds the binaries with upstream's own build script (`hyperbole.py build -r`, through `.github/pasadizo/build.sh`): static, stripped, `-trimpath`, with the version, the build date, the commit and the toolchain in `hysteria version`. A release has:

- `hysteria-linux-amd64` and `hysteria-linux-arm64`, the same names that upstream's releases use;
- a `SHA256SUMS` file;
- a GitHub build provenance attestation for each binary (`gh attestation verify hysteria-linux-amd64 --repo pasadizo-net/hysteria`).

Check a download with `sha256sum --ignore-missing -c SHA256SUMS`. The binary is a drop-in replacement for upstream's binary of the same version: the configuration and the command line are the same.

Upstream's `release.yml`, `docker.yml` and `autotag.yaml` workflows and its Dependabot configuration are removed here, because they would run on this repository's tags and publish to upstream's download bucket, API and Docker Hub. Upstream's other workflows run only on its `master` and `exp/*` branches, so they do not run here.

## Building

```sh
.github/pasadizo/build.sh                  # linux/amd64 and linux/arm64 into build/, with build/SHA256SUMS
.github/pasadizo/build.sh darwin/arm64     # any platform that hyperbole.py knows
cd extras && go test -race ./outbounds/... # the tests of the changed package
```

The version is the nearest `app/v*` tag, so a release build needs the tag and the history up to it.

## Following upstream

For a new upstream release, start a branch from upstream's new tag, cherry-pick the fix and the commit that adds this README and the workflows, and tag the result `app/v<version>-pasadizo.1`.

## License

MIT, as upstream ([LICENSE.md](../LICENSE.md)). Hysteria is by its authors; this repository adds only the change above.
