module github.com/apernet/hysteria/extras/v2

go 1.27.4

require (
	github.com/apernet/hysteria/core/v2 v2.0.0-00010101000000-000000000000
	github.com/apernet/quic-go v0.65.1-0.20261109005002-2895f039137a
	github.com/database64128/tfo-go/v2 v2.4.2
	github.com/expr-lang/expr v1.18.1
	github.com/hashicorp/golang-lru/v2 v2.0.7
	github.com/libp2p/go-nat v1.0.1-0.20250821073202-01afc089f138
	github.com/miekg/dns v1.1.73
	github.com/pion/stun/v3 v3.1.7
	github.com/stretchr/testify v1.12.1
	github.com/txthinking/socks5 v0.0.0-20260601051520-339b044ab0eb
	golang.org/x/crypto v0.59.0
	golang.org/x/net v0.63.0
	google.golang.org/protobuf v1.36.12
)

require (
	github.com/andybalholm/brotli v1.3.0 // indirect
	github.com/database64128/netx-go v0.1.1 // indirect
	github.com/huin/goupnp v1.3.1 // indirect
	github.com/jackpal/go-nat-pmp v1.1.0 // indirect
	github.com/klauspost/compress v1.20.5 // indirect
	github.com/koron/go-ssdp v0.9.2 // indirect
	github.com/libp2p/go-netroute v0.4.0 // indirect
	github.com/patrickmn/go-cache v2.1.0+incompatible // indirect
	github.com/pion/dtls/v3 v3.1.16 // indirect
	github.com/pion/logging v0.2.4 // indirect
	github.com/pion/transport/v4 v4.1.3 // indirect
	github.com/pion/transport/v5 v5.1.6 // indirect
	github.com/quic-go/qpack v0.6.0 // indirect
	github.com/refraction-networking/utls v1.8.2 // indirect
	github.com/stretchr/objx v0.8.0 // indirect
	github.com/txthinking/runnergroup v0.0.0-20250224021307-5864ffeb65ae // indirect
	github.com/wlynxg/anet v0.0.5 // indirect
	go.yaml.in/yaml/v3 v3.0.6 // indirect
	golang.org/x/exp v0.0.0-20261128033645-f63ec7c7eed0 // indirect
	golang.org/x/sync v0.25.0 // indirect
	golang.org/x/sys v0.50.0 // indirect
	golang.org/x/text v0.44.0 // indirect
)

replace github.com/apernet/hysteria/core/v2 => ../core
