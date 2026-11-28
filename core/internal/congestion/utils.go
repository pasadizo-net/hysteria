package congestion

import (
	"fmt"
	"strings"
	"time"

	"github.com/apernet/hysteria/core/v2/internal/congestion/bbr"
	"github.com/apernet/hysteria/core/v2/internal/congestion/brutal"
	"github.com/apernet/quic-go"
	"github.com/apernet/quic-go/congestion"
)

const (
	TypeBBR  = "bbr"
	TypeReno = "reno"
)

func NormalizeType(congestionType string) (string, error) {
	switch normalized := strings.ToLower(congestionType); normalized {
	case "", TypeBBR:
		return TypeBBR, nil
	case TypeReno:
		return TypeReno, nil
	default:
		return "", fmt.Errorf("unsupported congestion type %q", congestionType)
	}
}

func NormalizeBBRProfile(profile string) (string, error) {
	normalized, err := bbr.ParseProfile(profile)
	if err != nil {
		return "", err
	}
	return string(normalized), nil
}

// CarefulResumeStore keeps the congestion control parameters that BBR saves
// for Careful Resume (RFC 9959), one set per peer address.
type CarefulResumeStore = bbr.CarefulResumeStore

// DefaultCarefulResumeLifetime is the lifetime of saved parameters when the
// configuration does not set one.
const DefaultCarefulResumeLifetime = bbr.DefaultCarefulResumeLifetime

// NewCarefulResumeStore makes a store for Careful Resume. See
// bbr.NewCarefulResumeStore.
func NewCarefulResumeStore(lifetime time.Duration, stateFile string, log func(format string, a ...any)) *CarefulResumeStore {
	return bbr.NewCarefulResumeStore(lifetime, stateFile, log)
}

// UseBBR makes conn use BBR. With a non-nil carefulResume, BBR also uses
// Careful Resume with the parameters saved there.
func UseBBR(conn *quic.Conn, profile bbr.Profile, carefulResume *CarefulResumeStore) {
	initialPacketSize := seedPacketSize(conn.InitialPacketSize(), bbr.GetInitialPacketSize(conn.RemoteAddr()))
	if carefulResume != nil {
		conn.SetCongestionControl(bbr.NewBbrSenderWithCarefulResume(
			bbr.DefaultClock{},
			initialPacketSize,
			profile,
			carefulResume,
			conn.RemoteAddr(),
		))
		return
	}
	conn.SetCongestionControl(bbr.NewBbrSender(
		bbr.DefaultClock{},
		initialPacketSize,
		profile,
	))
}

// seedPacketSize picks the datagram size to seed a replacement congestion
// controller with, given the size QUIC itself starts at and the guess derived
// from the remote address.
//
// The seed must not exceed what QUIC actually starts at. If it does, the first
// path MTU probe can land between the two: QUIC sees an increase and reports
// it, but the controller sees a decrease, which it cannot represent. Taking the
// smaller of the two keeps the address-based guess as a floor for connections
// whose path we can't reason about, while never seeding above QUIC.
func seedPacketSize(quicSize, byAddr congestion.ByteCount) congestion.ByteCount {
	if quicSize <= 0 {
		return byAddr
	}
	return min(quicSize, byAddr)
}

func UseBrutal(conn *quic.Conn, tx uint64, disableLossCompensation bool) {
	conn.SetCongestionControl(brutal.NewBrutalSender(tx, disableLossCompensation))
}

func UseConfigured(conn *quic.Conn, congestionType, bbrProfile string, carefulResume *CarefulResumeStore) {
	switch congestionType {
	case TypeReno:
		return
	default:
		UseBBR(conn, bbr.Profile(bbrProfile), carefulResume)
	}
}
