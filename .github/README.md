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

This repository is [Hysteria](https://github.com/HyNetworks/hysteria) 2 with the changes that the Hysteria servers of [Pasadizo](https://github.com/pasadizo-net/pasadizo) gateways need. It is upstream's history up to a release tag (today `app/v2.14.0`), and each change is one commit on top of it.

**This repository is not affiliated with Hysteria or its authors**, and it is not endorsed by them. Report problems with this build here, never upstream. For everything else (the protocol, the configuration, the documentation) see [upstream](https://github.com/HyNetworks/hysteria) and [v2.hysteria.network](https://v2.hysteria.network/).

## The changes

| Change | Files |
| --- | --- |
| The `direct` outbound resolves a UDP destination host name once per UDP session, not once per packet. | `extras/outbounds/ob_direct.go`, `extras/outbounds/ob_direct_udp_test.go` |
| Careful Resume ([RFC 9959](https://www.rfc-editor.org/rfc/rfc9959)) for BBR on the server, off unless `congestion.carefulResume.enabled` is set. | `core/internal/congestion/bbr/careful_resume*.go`, `core/internal/congestion/bbr/bbr_sender.go`, `core/internal/congestion/utils.go`, `core/server/`, `app/cmd/server.go` |

### A UDP host name is resolved once

Upstream resolves a host name again for every UDP packet and uses the first address of each answer. For a name with several A or AAAA records (`www.google.com`, for example) the packets of one flow then go to different server addresses, and a QUIC handshake sent this way never completes, so HTTP/3 breaks. Clients that send names instead of addresses, such as sing-box or Pasadizo with sniffing or FakeIP, hit this on every HTTP/3 request.

With the fix, the address a name resolves to first is kept for the life of the UDP session and used for every later packet to that name, on any port. A failed resolution is not kept, so the next packet resolves the name again. The cache holds at most 256 names per session. The fix is in the outbound's own resolver, which is used when the server has no `resolver` section. When a `resolver` section (`udp`, `tcp`, `tls` or `https`) has already resolved the name, or an ACL rule has replaced it with an address, the packet carries that address and is handled as upstream handles it.

The commit is written so that it can be offered upstream as it is.

### Careful Resume

A new QUIC connection starts BBR from slow start: on a path of 100 ms and 200 Mbit/s it takes about two seconds to reach full speed, and every restart of a client, every failover and every deploy starts all its connections again. With Careful Resume the server saves the bottleneck bandwidth and the minimum RTT that BBR measures to each client address, and a new connection from the same address starts from half of that bandwidth once the path is confirmed. It applies to downloads (server to client) on BBR, which is what a client gets when it does not set `down_mbps`; a client that asks for Brutal is not affected.

```yaml
congestion:
  type: bbr
  carefulResume:
    enabled: true # default false
    lifetime: 10m # how long saved values may be reused after the last observation; default 10m
    stateFile: /var/lib/hysteria/careful-resume.json # optional: keeps the values across restarts
```

It follows the phases of the RFC and its notes for BBR (Appendix C):

- **Observing.** While a connection is in BBR's `PROBE_BW`, each round saves its bottleneck bandwidth, its minimum RTT and their product (`saved_cwnd`) for the client's IP address. The port is not part of the key, because a new connection comes from a new port. A sample taken while the sender was application limited replaces a saved value only when it is larger, and a path under four initial windows is not saved.
- **Reconnaissance.** A new connection from that address takes the saved values; only one connection at a time may use them (a claim runs out after 30 s). It sends as plain BBR. When the initial window is acknowledged, the path is confirmed if the minimum RTT is more than half and at most ten times the saved one.
- **Unvalidated.** When the connection has more to send than BBR allows, while still in `STARTUP`, the window jumps to half the saved window and the pacing rate to half the saved bandwidth (never more than the jump window per current RTT), for at most one RTT.
- **Validating.** The window is set to what is in flight and grows with the ACKs until the last unvalidated packet is acknowledged; then BBR goes on with the larger window.
- **Safe Retreat.** Congestion during the jump deletes the saved values, cuts the window to half of what was delivered, discards BBR's bandwidth samples of the jump and moves BBR to `DRAIN`. When the jump's last packet is acknowledged, BBR goes on from half the delivered rate.

One deviation from the RFC: loss counts as congestion only when at least 8 packets and more than 5 % of the acknowledged or lost bytes of the connection were lost. The RFC gives any packet loss as an example of congestion, but on the lossy paths this build is for a few per cent are lost at random whatever the sender does, and BBR itself does not treat such loss as congestion. Persistent congestion is seen through this loss rule, because quic-go does not report retransmission timeouts to the congestion controller.

`HYSTERIA_BBR_DEBUG=1` prints each phase change. Measured in two network namespaces with netem (200 Mbit/s, 100 ms RTT, a new client connection after a 6 s download, 8 reconnects each):

| Loss | | First second | First 2 s | First 5 s | Time to 90 % of full rate |
| --- | --- | --- | --- | --- | --- |
| 1 % | without | 6.7 MB | 21.9 MB | 77.0 MB | 1.6 s |
| 1 % | with | 12.1 MB | 30.5 MB | 88.2 MB | 0.9 s |
| 3 % | without | 4.8 MB | 20.2 MB | 72.4 MB | 1.8 s |
| 3 % | with | 10.4 MB | 27.9 MB | 81.9 MB | 1.2 s |

All 16 resumed connections were validated; none retreated. When the capacity had fallen to 20 Mbit/s with a 100 ms queue before the reconnect, every resumed connection went to Safe Retreat: its first second carried 0.4–0.5 MB against 1.3–1.4 MB without Careful Resume, the bottleneck dropped about 950 packets against 130, and from the second second on both carried the same.

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
cd extras && go test -race ./outbounds/... # the tests of the changed packages
cd core && go test -race ./internal/congestion/... ./server/...
cd app && go test ./cmd/
```

The version is the nearest `app/v*` tag, so a release build needs the tag and the history up to it.

## Following upstream

Every Monday `pasadizo-sync` looks for a new upstream release (a tag `app/vX.Y.Z`). When there is one, it merges the tag into a branch `sync/app-vX.Y.Z`, builds and tests it, and opens a pull request; on a merge conflict it opens an issue instead. After the pull request is merged, tag `main` as `app/vX.Y.Z-pasadizo.1` to release it. It can also be started by hand (Actions, pasadizo-sync, Run workflow).

## License

MIT, as upstream ([LICENSE.md](../LICENSE.md)). Hysteria is by its authors; this repository adds only the changes above.
