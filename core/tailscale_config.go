package core

import (
	"path/filepath"
	"strconv"
	"strings"

	"github.com/metacubex/mihomo/common/orderedmap"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

const (
	tailscaleMagicDNSSuffix = "ts.net"
	tailscaleIPRange        = "100.64.0.0/10"
	tailscaleIPRange6       = "fd7a:115c:a1e0::/48"
	tailscaleProxyPrefix    = "Tailscale-"
	tailscaleGroupBase      = "Tailscale"
	tailscaleNameMaxLength  = 48
)

// Injected here, not in a profile, so the rules precede every profile rule;
// nothing written to config.yaml carries the auth key.
func injectTailscaleConfig(raw *config.RawConfig) {
	networks := tailscale.snapshot()
	if len(networks) == 0 {
		tailscale.setInjection(tailscaleInjection{})
		return
	}

	used := make(map[string]struct{}, len(raw.Proxy)+len(raw.ProxyGroup)+len(networks)+4)
	for _, mapping := range raw.Proxy {
		if name, ok := mapping["name"].(string); ok {
			used[name] = struct{}{}
		}
	}
	for _, mapping := range raw.ProxyGroup {
		if name, ok := mapping["name"].(string); ok {
			used[name] = struct{}{}
		}
	}
	for _, reserved := range []string{"DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE", "GLOBAL"} {
		used[reserved] = struct{}{}
	}

	group := uniqueTailscaleName(used, tailscaleGroupBase)
	proxies := make(map[string]string, len(networks))
	members := make([]string, 0, len(networks))
	for _, network := range networks {
		name := uniqueTailscaleName(used, tailscaleProxyName(network))
		proxies[network.ID] = name
		members = append(members, name)
		raw.Proxy = append(raw.Proxy, tailscaleProxyConfig(network, name))
	}
	raw.ProxyGroup = append(raw.ProxyGroup, map[string]any{
		"name":    group,
		"type":    "select",
		"proxies": members,
	})

	rules := []string{
		"DOMAIN-SUFFIX," + tailscaleMagicDNSSuffix + "," + group,
		"IP-CIDR," + tailscaleIPRange + "," + group + ",no-resolve",
		"IP-CIDR6," + tailscaleIPRange6 + "," + group + ",no-resolve",
	}
	raw.Rule = append(rules, raw.Rule...)

	// Keep MagicDNS out of the fake pool: the tailnet hands out the address.
	lookup := "+." + tailscaleMagicDNSSuffix
	dnsProxy := members[0]
	if raw.DNS.NameServerPolicy == nil {
		raw.DNS.NameServerPolicy = orderedmap.New[string, any]()
	}
	raw.DNS.NameServerPolicy.Set(lookup, []string{"tailscale://" + dnsProxy})
	raw.DNS.NameServerPolicy.MoveToFront(lookup)
	if !containsTailscaleFilter(raw.DNS.FakeIPFilter, lookup) {
		raw.DNS.FakeIPFilter = append(raw.DNS.FakeIPFilter, lookup)
	}

	tailscale.setInjection(tailscaleInjection{
		group:   group,
		proxies: proxies,
	})
}

// An apply does not close the proxies it replaces, and a tailscale outbound
// keeps its backend and DNS registration alive until Close.
func closeReplacedTailscaleProxies(previous map[string]C.Proxy) {
	current := tunnel.AllProxies()
	for name, proxy := range previous {
		if proxy.Type() != C.Tailscale {
			continue
		}
		if kept, ok := current[name]; ok && kept == proxy {
			continue
		}
		_ = proxy.Close()
	}
}

func tailscaleProxyConfig(network TailscaleNetworkParams, name string) map[string]any {
	mapping := map[string]any{
		"name":                       name,
		"type":                       "tailscale",
		"hostname":                   network.Hostname,
		"state-dir":                  filepath.Join(tailscaleStateDirName, network.ID),
		"udp":                        true,
		"accept-routes":              network.AcceptRoutes,
		"exit-node-allow-lan-access": network.ExitNodeAllowLANAccess,
	}
	if network.AuthKey != "" {
		mapping["auth-key"] = network.AuthKey
	}
	if network.ControlURL != "" {
		mapping["control-url"] = network.ControlURL
	}
	if network.ExitNode != "" {
		mapping["exit-node"] = network.ExitNode
	}
	return mapping
}

// The name doubles as the key of the DNS client the tailscale outbound
// registers and as the host of its tailscale:// URI, so it must stay URL-safe.
func tailscaleProxyName(network TailscaleNetworkParams) string {
	base := strings.TrimSpace(network.Name)
	if base == "" {
		base = network.ID
	}
	var builder strings.Builder
	builder.WriteString(tailscaleProxyPrefix)
	for _, char := range base {
		switch {
		case char >= 'a' && char <= 'z':
		case char >= 'A' && char <= 'Z':
		case char >= '0' && char <= '9':
		case char == '-' || char == '_':
		default:
			char = '-'
		}
		builder.WriteRune(char)
		if builder.Len() >= tailscaleNameMaxLength {
			break
		}
	}
	return strings.TrimRight(builder.String(), "-")
}

func uniqueTailscaleName(used map[string]struct{}, base string) string {
	name := base
	for suffix := 2; ; suffix++ {
		if _, exists := used[name]; !exists {
			break
		}
		name = base + "-" + strconv.Itoa(suffix)
	}
	used[name] = struct{}{}
	return name
}

func containsTailscaleFilter(filters []string, lookup string) bool {
	for _, filter := range filters {
		if strings.EqualFold(strings.TrimSpace(filter), lookup) {
			return true
		}
	}
	return false
}
