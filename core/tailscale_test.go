package core

import (
	"net/netip"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/tailscale/ipn/ipnstate"
	"github.com/metacubex/tailscale/tailcfg"
)

func TestTailscaleStateOf(t *testing.T) {
	cases := map[string]string{
		"Running":           tailscaleStateRunning,
		"Starting":          tailscaleStateStarting,
		"NeedsLogin":        tailscaleStateNeedsLogin,
		"NeedsMachineAuth":  tailscaleStateNeedsApproval,
		"Stopped":           tailscaleStateStopped,
		"InUseOtherUser":    tailscaleStateError,
		"NoState":           tailscaleStateStarting,
		"":                  tailscaleStateStarting,
		"  Running  ":       "  running  ",
		"unexpected-string": "unexpected-string",
	}
	for raw, want := range cases {
		if got := tailscaleStateOf(raw); got != want {
			t.Fatalf("tailscaleStateOf(%q) = %q, want %q", raw, got, want)
		}
	}
}

func TestTailscaleDeviceOf(t *testing.T) {
	peer := &ipnstate.PeerStatus{
		ID:       tailcfg.StableNodeID("n123"),
		HostName: "laptop",
		DNSName:  "laptop.tailnet.ts.net.",
		OS:       "linux",
		Online:   true,
		CurAddr:  "192.0.2.10:41641",
		Relay:    "tok",
		TailscaleIPs: []netip.Addr{
			netip.MustParseAddr("100.64.0.2"),
			netip.MustParseAddr("fd7a:115c:a1e0::2"),
		},
		ExitNodeOption: true,
	}
	device := tailscaleDeviceOf(peer)
	if device.ID != "n123" || device.Name != "laptop.tailnet.ts.net" {
		t.Fatalf("unexpected identity: %+v", device)
	}
	if device.Hostname != "laptop" || device.OS != "linux" || !device.Online {
		t.Fatalf("unexpected metadata: %+v", device)
	}
	if !device.Direct || device.Relay != "tok" || !device.ExitNodeOption {
		t.Fatalf("unexpected connection state: %+v", device)
	}
	if got := strings.Join(device.IPs, ","); got != "100.64.0.2,fd7a:115c:a1e0::2" {
		t.Fatalf("unexpected IPs: %q", got)
	}
}

func TestTailscaleDeviceOfFallsBackToHostname(t *testing.T) {
	device := tailscaleDeviceOf(&ipnstate.PeerStatus{HostName: "phone", Relay: "hkg"})
	if device.Name != "phone" {
		t.Fatalf("name = %q, want the hostname", device.Name)
	}
	if device.Direct {
		t.Fatal("a peer without CurAddr is not a direct connection")
	}
	if device.IPs == nil || len(device.IPs) != 0 {
		t.Fatalf("IPs = %#v, want an empty list", device.IPs)
	}
}

func TestTailscaleControlTarget(t *testing.T) {
	cases := map[string]string{
		"":                                   "controlplane.tailscale.com:443",
		"https://controlplane.tailscale.com": "controlplane.tailscale.com:443",
		"https://hs.example.com":             "hs.example.com:443",
		"http://hs.example.com":              "hs.example.com:80",
		"https://hs.example.com:8443":        "hs.example.com:8443",
		"not a url":                          "controlplane.tailscale.com:443",
	}
	for controlURL, want := range cases {
		if got := tailscaleControlTarget(controlURL); got != want {
			t.Fatalf("tailscaleControlTarget(%q) = %q, want %q", controlURL, got, want)
		}
	}
}

func withTailscaleNetworks(t *testing.T, networks []TailscaleNetworkParams) {
	t.Helper()
	tailscale.mu.Lock()
	saved := tailscale.networks
	savedInjection := tailscale.injected
	tailscale.networks = networks
	tailscale.injected = tailscaleInjection{}
	tailscale.mu.Unlock()
	t.Cleanup(func() {
		tailscale.mu.Lock()
		tailscale.networks = saved
		tailscale.injected = savedInjection
		tailscale.mu.Unlock()
	})
}

func TestInjectTailscaleConfig(t *testing.T) {
	withTailscaleNetworks(t, []TailscaleNetworkParams{
		{
			ID:           "home",
			Name:         "Home Lab",
			Hostname:     "phone",
			AuthKey:      "tskey-test-key",
			AcceptRoutes: true,
		},
		{ID: "work", Name: "Work", Hostname: "phone"},
	})
	raw := config.DefaultRawConfig()
	raw.Rule = []string{"MATCH,DIRECT"}

	injectTailscaleConfig(raw)

	injection := tailscale.injection()
	home := injection.proxies["home"]
	work := injection.proxies["work"]
	if home != "Tailscale-Home-Lab" || work != "Tailscale-Work" {
		t.Fatalf("unexpected proxy names: %q, %q", home, work)
	}
	if injection.group != "Tailscale" {
		t.Fatalf("unexpected injection: %+v", injection)
	}

	if len(raw.Proxy) != 2 || len(raw.ProxyGroup) != 1 {
		t.Fatalf("proxies = %d, groups = %d, want 2 and 1", len(raw.Proxy), len(raw.ProxyGroup))
	}
	first := raw.Proxy[0]
	if first["type"] != "tailscale" || first["state-dir"] != "tailscale/home" {
		t.Fatalf("unexpected proxy mapping: %#v", first)
	}
	if first["auth-key"] != "tskey-test-key" || first["udp"] != true || first["accept-routes"] != true {
		t.Fatalf("unexpected proxy options: %#v", first)
	}
	group := raw.ProxyGroup[0]
	if group["name"] != "Tailscale" || group["type"] != "select" {
		t.Fatalf("unexpected group: %#v", group)
	}
	if members, ok := group["proxies"].([]string); !ok || len(members) != 2 || members[0] != home || members[1] != work {
		t.Fatalf("unexpected group members: %#v", group["proxies"])
	}

	wantRules := []string{
		"DOMAIN-SUFFIX,ts.net,Tailscale",
		"IP-CIDR,100.64.0.0/10,Tailscale,no-resolve",
		"IP-CIDR6,fd7a:115c:a1e0::/48,Tailscale,no-resolve",
		"MATCH,DIRECT",
	}
	if strings.Join(raw.Rule, "|") != strings.Join(wantRules, "|") {
		t.Fatalf("rules = %#v, want the tailnet rules first", raw.Rule)
	}

	value, ok := raw.DNS.NameServerPolicy.Get("+.ts.net")
	if !ok {
		t.Fatal("nameserver-policy has no ts.net entry")
	}
	if servers, ok := value.([]string); !ok || len(servers) != 1 || servers[0] != "tailscale://"+home {
		t.Fatalf("nameserver-policy = %#v", value)
	}
	if !containsTailscaleFilter(raw.DNS.FakeIPFilter, "+.ts.net") {
		t.Fatalf("fake-ip-filter = %#v, want the MagicDNS suffix", raw.DNS.FakeIPFilter)
	}
}

func TestInjectTailscaleConfigAvoidsProfileNames(t *testing.T) {
	withTailscaleNetworks(t, []TailscaleNetworkParams{
		{ID: "home", Name: "Home", Hostname: "phone"},
	})
	raw := config.DefaultRawConfig()
	raw.Proxy = []map[string]any{{"name": "Tailscale-Home", "type": "direct"}}
	raw.ProxyGroup = []map[string]any{{"name": "Tailscale", "type": "select"}}

	injectTailscaleConfig(raw)

	injection := tailscale.injection()
	if injection.proxies["home"] != "Tailscale-Home-2" {
		t.Fatalf("proxy name = %q, want it to step around the profile", injection.proxies["home"])
	}
	if injection.group != "Tailscale-2" {
		t.Fatalf("group = %q, want it to step around the profile", injection.group)
	}
}

func TestInjectTailscaleConfigWithoutNetworks(t *testing.T) {
	withTailscaleNetworks(t, nil)
	raw := config.DefaultRawConfig()
	raw.Rule = []string{"MATCH,DIRECT"}

	injectTailscaleConfig(raw)

	if len(raw.Proxy) != 0 || len(raw.Rule) != 1 || raw.Rule[0] != "MATCH,DIRECT" {
		t.Fatalf("an empty network list changed the config: %#v", raw)
	}
	if tailscale.injection().group != "" {
		t.Fatalf("injection = %+v, want it cleared", tailscale.injection())
	}
}

func TestTailscaleProxyOfUnwrapsParsedProxy(t *testing.T) {
	proxy, err := adapter.ParseProxy(map[string]any{"name": "direct-1", "type": "direct"})
	if err != nil {
		t.Fatalf("parse proxy: %v", err)
	}
	if _, ok := tailscaleProxyOf(proxy); ok {
		t.Fatal("a direct proxy is not a tailscale network")
	}
	if _, ok := tailscaleProxyOf(nil); ok {
		t.Fatal("a missing proxy is not a tailscale network")
	}
	if _, ok := outbound.UnwrapProxyAdapter(proxy.Adapter()).(*outbound.Direct); !ok {
		t.Fatalf("unwrapped adapter is %T, want *outbound.Direct", outbound.UnwrapProxyAdapter(proxy.Adapter()))
	}
}

func TestTailscaleProxyName(t *testing.T) {
	cases := map[string]string{
		"Home Lab":  "Tailscale-Home-Lab",
		"  work-1":  "Tailscale-work-1",
		"家用网络":      "Tailscale",
		"../../etc": "Tailscale-------etc",
	}
	for name, want := range cases {
		got := tailscaleProxyName(TailscaleNetworkParams{ID: "abc", Name: name})
		if got != want {
			t.Fatalf("tailscaleProxyName(%q) = %q, want %q", name, got, want)
		}
	}
}

func TestTailscaleHostnameOf(t *testing.T) {
	cases := map[string]string{
		"":        "flclash-abc",
		"   ":     "flclash-abc",
		"phone":   "phone",
		" Phone ": "Phone",
	}
	for hostname, want := range cases {
		got := tailscaleHostnameOf(TailscaleNetworkParams{ID: "abc", Hostname: hostname})
		if got != want {
			t.Fatalf("tailscaleHostnameOf(%q) = %q, want %q", hostname, got, want)
		}
	}
	got := tailscaleHostnameOf(TailscaleNetworkParams{ID: "ABC"})
	if got != "flclash-abc" {
		t.Fatalf("default hostname = %q, want it lowercased", got)
	}
}

func TestValidateTailscaleNetwork(t *testing.T) {
	valid := []TailscaleNetworkParams{
		{ID: "home"},
		{ID: "home_lab-1"},
		{ID: "home", ControlURL: "https://hs.example.com"},
		{ID: "home", ControlURL: "http://hs.example.com:8080"},
		{ID: "home", ControlURL: "  https://hs.example.com  "},
	}
	for _, network := range valid {
		if err := validateTailscaleNetwork(network); err != nil {
			t.Fatalf("validateTailscaleNetwork(%+v) = %v, want nil", network, err)
		}
	}

	invalid := []TailscaleNetworkParams{
		{ID: ""},
		{ID: "has space"},
		{ID: "has/slash"},
		{ID: strings.Repeat("a", 65)},
		{ID: "home", ControlURL: "ftp://hs.example.com"},
		{ID: "home", ControlURL: "hs.example.com"},
		{ID: "home", ControlURL: "https://"},
	}
	for _, network := range invalid {
		if err := validateTailscaleNetwork(network); err == nil {
			t.Fatalf("validateTailscaleNetwork(%+v) accepted an invalid network", network)
		}
	}
}
