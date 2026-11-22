package core

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/tailscale/ipn/ipnstate"
)

const (
	tailscaleStatusTimeout  = 5 * time.Second
	tailscaleLoginTimeout   = 15 * time.Second
	tailscaleLogoutTimeout  = 15 * time.Second
	tailscaleCheckTimeout   = 10 * time.Second
	tailscaleDefaultControl = "https://controlplane.tailscale.com"
	tailscaleAutoExitNode   = "auto"
	tailscaleStateDirName   = "tailscale"
	tailscaleNetworksFile   = "networks.json"
	tailscaleMaxHealth      = 3
)

type TailscaleNetworkParams struct {
	ID                     string `json:"id"`
	Name                   string `json:"name"`
	Hostname               string `json:"hostname"`
	ControlURL             string `json:"control-url"`
	AuthKey                string `json:"auth-key"`
	LoginMethod            string `json:"login-method"`
	ExitNode               string `json:"exit-node"`
	AcceptRoutes           bool   `json:"accept-routes"`
	ExitNodeAllowLANAccess bool   `json:"exit-node-allow-lan-access"`
}

type TailscaleNetworksParams struct {
	Networks []TailscaleNetworkParams `json:"networks"`
}

type TailscaleDevice struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Hostname       string   `json:"hostname"`
	OS             string   `json:"os"`
	IPs            []string `json:"ips"`
	Online         bool     `json:"online"`
	Direct         bool     `json:"direct"`
	Relay          string   `json:"relay,omitempty"`
	ExitNode       bool     `json:"exit-node"`
	ExitNodeOption bool     `json:"exit-node-option"`
}

type TailscaleNetworkStatus struct {
	ID                     string            `json:"id"`
	State                  string            `json:"state"`
	RawState               string            `json:"raw-state,omitempty"`
	LoginMethod            string            `json:"login-method"`
	AuthURL                string            `json:"auth-url,omitempty"`
	Error                  string            `json:"error,omitempty"`
	Health                 []string          `json:"health,omitempty"`
	Account                string            `json:"account,omitempty"`
	Tailnet                string            `json:"tailnet,omitempty"`
	Hostname               string            `json:"hostname"`
	ExitNode               string            `json:"exit-node"`
	ExitNodeActive         string            `json:"exit-node-active,omitempty"`
	AcceptRoutes           bool              `json:"accept-routes"`
	ExitNodeAllowLANAccess bool              `json:"exit-node-allow-lan-access"`
	Online                 bool              `json:"online"`
	Self                   *TailscaleDevice  `json:"self,omitempty"`
	Devices                []TailscaleDevice `json:"devices"`
	ExitNodes              []TailscaleDevice `json:"exit-nodes"`
}

type TailscaleStatusResult struct {
	Networks []TailscaleNetworkStatus `json:"networks"`
}

type TailscaleCheck struct {
	Code        string `json:"code"`
	Message     string `json:"message,omitempty"`
	Delay       int64  `json:"delay,omitempty"`
	Peers       int    `json:"peers"`
	OnlinePeers int    `json:"online-peers"`
}

const (
	tailscaleStateStopped       = "stopped"
	tailscaleStateStarting      = "starting"
	tailscaleStateNeedsLogin    = "needs-login"
	tailscaleStateNeedsApproval = "needs-approval"
	tailscaleStateRunning       = "running"
	tailscaleStateError         = "error"

	tailscaleCheckHealthy       = "healthy"
	tailscaleCheckNotApplied    = "not-applied"
	tailscaleCheckUnavailable   = "unavailable"
	tailscaleCheckOffline       = "offline"
	tailscaleCheckExitNodeUnset = "exit-node-unset"
)

// tailscaleInjection records the proxy names the running config was built
// with. The names depend on the network set and on what the profile already
// declares, so lookups go through this instead of deriving them again.
type tailscaleInjection struct {
	group   string
	proxies map[string]string
}

func (i tailscaleInjection) proxyOf(id string) string {
	return i.proxies[id]
}

type tailscaleManager struct {
	mu       sync.Mutex
	networks []TailscaleNetworkParams
	injected tailscaleInjection
	removed  []string
}

var tailscale = &tailscaleManager{}

func handleApplyTailscale(params *TailscaleNetworksParams) error {
	if !isInit.Load() {
		return errNotInitialized
	}
	return tailscale.apply(params.Networks)
}

func handleGetTailscaleStatus() *TailscaleStatusResult {
	return &TailscaleStatusResult{Networks: tailscale.statuses()}
}

func handleTailscaleLogin(params *IDParams) error {
	if !isInit.Load() {
		return errNotInitialized
	}
	proxy, err := tailscale.proxyOf(params.ID)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleLoginTimeout)
	defer cancel()
	return proxy.TailscaleStartLogin(ctx)
}

func handleTailscaleLogout(params *IDParams) error {
	if !isInit.Load() {
		return errNotInitialized
	}
	proxy, err := tailscale.proxyOf(params.ID)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleLogoutTimeout)
	defer cancel()
	return proxy.TailscaleLogout(ctx)
}

func handleForgetTailscale(params *IDParams) error {
	if !isInit.Load() {
		return errNotInitialized
	}
	return tailscale.forget(params.ID)
}

func handleCheckTailscale(params *IDParams) (*TailscaleCheck, error) {
	if !isInit.Load() {
		return nil, errNotInitialized
	}
	return tailscale.check(params.ID)
}

func (m *tailscaleManager) apply(networks []TailscaleNetworkParams) error {
	desired := make([]TailscaleNetworkParams, 0, len(networks))
	seen := make(map[string]struct{}, len(networks))
	for _, network := range networks {
		if err := validateTailscaleNetwork(network); err != nil {
			return err
		}
		if _, exists := seen[network.ID]; exists {
			return &MethodError{Code: "invalid_arguments", Message: fmt.Sprintf("duplicate tailscale network id %q", network.ID)}
		}
		seen[network.ID] = struct{}{}
		network.Hostname = tailscaleHostnameOf(network)
		desired = append(desired, network)
	}
	sort.Slice(desired, func(i, j int) bool {
		return desired[i].ID < desired[j].ID
	})

	m.mu.Lock()
	changed := !equalTailscaleNetworks(desired, m.networks)
	m.networks = desired
	m.mu.Unlock()
	if changed {
		m.save()
	}
	return nil
}

func equalTailscaleNetworks(a, b []TailscaleNetworkParams) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func (m *tailscaleManager) snapshot() []TailscaleNetworkParams {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]TailscaleNetworkParams(nil), m.networks...)
}

func (m *tailscaleManager) lookup(id string) (TailscaleNetworkParams, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, network := range m.networks {
		if network.ID == id {
			return network, nil
		}
	}
	return TailscaleNetworkParams{}, &MethodError{Code: "not_found", Message: fmt.Sprintf("tailscale network %q is not configured", id)}
}

func (m *tailscaleManager) injection() tailscaleInjection {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.injected
}

func (m *tailscaleManager) setInjection(injection tailscaleInjection) {
	m.mu.Lock()
	m.injected = injection
	m.mu.Unlock()
}

// proxyOf finds the outbound the running config built for a network. It is
// absent until a config that carries the network has been applied.
func (m *tailscaleManager) proxyOf(id string) (*outbound.Tailscale, error) {
	if _, err := m.lookup(id); err != nil {
		return nil, err
	}
	name := m.injection().proxyOf(id)
	if name == "" {
		return nil, &MethodError{Code: tailscaleCheckNotApplied, Message: "the tailscale network is not in the applied config"}
	}
	networkProxy, ok := tailscaleProxyOf(tunnel.AllProxies()[name])
	if !ok {
		return nil, &MethodError{Code: tailscaleCheckNotApplied, Message: "the tailscale network is not in the applied config"}
	}
	return networkProxy, nil
}

// The parser wraps every outbound in an auto-close adapter, so the tailscale
// methods sit on the outbound it holds rather than on the proxy itself.
func tailscaleProxyOf(proxy constant.Proxy) (*outbound.Tailscale, bool) {
	if proxy == nil {
		return nil, false
	}
	networkProxy, ok := outbound.UnwrapProxyAdapter(proxy.Adapter()).(*outbound.Tailscale)
	return networkProxy, ok
}

func (m *tailscaleManager) forget(id string) error {
	if !isTailscaleID(id) {
		return &MethodError{Code: "invalid_arguments", Message: "invalid tailscale network id"}
	}
	m.mu.Lock()
	kept := make([]TailscaleNetworkParams, 0, len(m.networks))
	found := false
	for _, network := range m.networks {
		if network.ID == id {
			found = true
			continue
		}
		kept = append(kept, network)
	}
	if found {
		m.networks = kept
		m.removed = append(m.removed, id)
	}
	m.mu.Unlock()
	if !found {
		return nil
	}
	m.save()
	return nil
}

// takeRemoved reports the state directories whose network left the config.
// The caller deletes them only after the outbound that used them is closed.
func (m *tailscaleManager) takeRemoved() []string {
	m.mu.Lock()
	removed := m.removed
	m.removed = nil
	m.mu.Unlock()
	return removed
}

func (m *tailscaleManager) statuses() []TailscaleNetworkStatus {
	networks := m.snapshot()
	injection := m.injection()
	statuses := make([]TailscaleNetworkStatus, 0, len(networks))
	for _, network := range networks {
		statuses = append(statuses, tailscaleNetworkStatus(network, injection))
	}
	return statuses
}

func tailscaleNetworkStatus(network TailscaleNetworkParams, injection tailscaleInjection) TailscaleNetworkStatus {
	status := TailscaleNetworkStatus{
		ID:                     network.ID,
		Hostname:               network.Hostname,
		LoginMethod:            network.LoginMethod,
		ExitNode:               network.ExitNode,
		AcceptRoutes:           network.AcceptRoutes,
		ExitNodeAllowLANAccess: network.ExitNodeAllowLANAccess,
		Devices:                []TailscaleDevice{},
		ExitNodes:              []TailscaleDevice{},
	}
	name := injection.proxyOf(network.ID)
	if name == "" {
		status.State = tailscaleStateStopped
		return status
	}
	networkProxy, ok := tailscaleProxyOf(tunnel.AllProxies()[name])
	if !ok {
		status.State = tailscaleStateStopped
		return status
	}

	ctx, cancel := context.WithTimeout(context.Background(), tailscaleStatusTimeout)
	defer cancel()
	current, err := networkProxy.TailscaleStatus(ctx)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			status.State = tailscaleStateStarting
		} else {
			status.State = tailscaleStateError
			status.Error = err.Error()
		}
		return status
	}
	applyTailscaleStatus(&status, current)
	status.RawState = current.BackendState
	status.AuthURL = current.AuthURL
	if status.State == "" {
		status.State = tailscaleStateOf(status.RawState)
	}
	if lastErr := networkProxy.TailscaleLastError(); lastErr != "" {
		status.Error = lastErr
	}
	if len(current.Health) > 0 {
		status.Health = current.Health[:min(len(current.Health), tailscaleMaxHealth)]
	}
	return status
}

func (m *tailscaleManager) check(id string) (*TailscaleCheck, error) {
	network, err := m.lookup(id)
	if err != nil {
		return nil, err
	}
	status := tailscaleNetworkStatus(network, m.injection())
	check := &TailscaleCheck{
		Code:    tailscaleCheckUnavailable,
		Peers:   len(status.Devices),
		Message: status.Error,
	}
	for _, device := range status.Devices {
		if device.Online {
			check.OnlinePeers++
		}
	}
	switch status.State {
	case tailscaleStateNeedsLogin, tailscaleStateNeedsApproval, tailscaleStateStarting, tailscaleStateStopped, tailscaleStateError:
		if status.State != tailscaleStateError {
			check.Code = status.State
		}
		if status.State == tailscaleStateStopped {
			check.Code = tailscaleCheckNotApplied
		}
		return check, nil
	}
	if !status.Online {
		check.Code = tailscaleCheckOffline
		return check, nil
	}
	if status.ExitNode != "" && status.ExitNodeActive == "" {
		check.Code = tailscaleCheckExitNodeUnset
		return check, nil
	}
	proxy, err := m.proxyOf(id)
	if err != nil {
		check.Code = tailscaleCheckNotApplied
		check.Message = err.Error()
		return check, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleCheckTimeout)
	defer cancel()
	start := time.Now()
	conn, err := proxy.TailscaleDial(ctx, "tcp", tailscaleControlTarget(network.ControlURL))
	if err != nil {
		check.Code = tailscaleCheckUnavailable
		check.Message = err.Error()
		return check, nil
	}
	_ = conn.Close()
	check.Code = tailscaleCheckHealthy
	check.Delay = time.Since(start).Milliseconds()
	check.Message = ""
	return check, nil
}

func validateTailscaleNetwork(network TailscaleNetworkParams) error {
	if !isTailscaleID(network.ID) {
		return &MethodError{Code: "invalid_arguments", Message: "invalid tailscale network id"}
	}
	controlURL := strings.TrimSpace(network.ControlURL)
	if controlURL == "" {
		return nil
	}
	parsed, err := url.Parse(controlURL)
	if err != nil || parsed.Host == "" || (parsed.Scheme != "http" && parsed.Scheme != "https") {
		return &MethodError{Code: "invalid_arguments", Message: "control URL must be an http or https URL"}
	}
	return nil
}

// tsnet would otherwise name the device after the Android host, which is
// "localhost" on every phone and lets two devices claim one tailnet name.
func tailscaleHostnameOf(network TailscaleNetworkParams) string {
	if hostname := strings.TrimSpace(network.Hostname); hostname != "" {
		return hostname
	}
	return "flclash-" + strings.ToLower(network.ID)
}

func isTailscaleID(id string) bool {
	if id == "" || len(id) > 64 {
		return false
	}
	for _, char := range id {
		switch {
		case char >= 'a' && char <= 'z':
		case char >= 'A' && char <= 'Z':
		case char >= '0' && char <= '9':
		case char == '-' || char == '_':
		default:
			return false
		}
	}
	return true
}

// The preferences belong to the Core, not to the running config: a headless
// start (the Android service applying the saved setup) has no host to send
// them and still has to route the tailnet.
func tailscaleNetworksPath() string {
	return filepath.Join(constant.Path.HomeDir(), tailscaleStateDirName, tailscaleNetworksFile)
}

func (m *tailscaleManager) load() {
	buf, err := os.ReadFile(tailscaleNetworksPath())
	if err != nil {
		return
	}
	var params TailscaleNetworksParams
	if err := json.Unmarshal(buf, &params); err != nil {
		log.Warnln("[Tailscale] read saved networks: %v", err)
		return
	}
	desired := make([]TailscaleNetworkParams, 0, len(params.Networks))
	for _, network := range params.Networks {
		if validateTailscaleNetwork(network) != nil {
			continue
		}
		network.AuthKey = ""
		network.Hostname = tailscaleHostnameOf(network)
		desired = append(desired, network)
	}
	sort.Slice(desired, func(i, j int) bool {
		return desired[i].ID < desired[j].ID
	})
	m.mu.Lock()
	m.networks = desired
	m.mu.Unlock()
}

func (m *tailscaleManager) save() {
	networks := m.snapshot()
	params := TailscaleNetworksParams{Networks: make([]TailscaleNetworkParams, 0, len(networks))}
	for _, network := range networks {
		// The auth key stays with the host; a saved state directory does not
		// need it to come back up.
		network.AuthKey = ""
		params.Networks = append(params.Networks, network)
	}
	buf, err := json.Marshal(params)
	if err != nil {
		log.Warnln("[Tailscale] encode saved networks: %v", err)
		return
	}
	path := tailscaleNetworksPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		log.Warnln("[Tailscale] create state directory: %v", err)
		return
	}
	if err := os.WriteFile(path, buf, 0o600); err != nil {
		log.Warnln("[Tailscale] save networks: %v", err)
	}
}

func tailscaleStateDir(id string) string {
	return filepath.Join(constant.Path.HomeDir(), tailscaleStateDirName, id)
}

func removeTailscaleState(id string) {
	if !isTailscaleID(id) {
		return
	}
	if err := os.RemoveAll(tailscaleStateDir(id)); err != nil {
		log.Warnln("[Tailscale] remove state for %s: %v", id, err)
	}
}

func applyTailscaleStatus(status *TailscaleNetworkStatus, current *ipnstate.Status) {
	if current.BackendState != "" {
		status.State = tailscaleStateOf(current.BackendState)
	}
	if current.CurrentTailnet != nil {
		status.Tailnet = current.CurrentTailnet.Name
	}
	self := current.Self
	if self != nil {
		status.Online = self.Online
		device := tailscaleDeviceOf(self)
		status.Self = &device
		if current.User != nil {
			if profile, ok := current.User[self.UserID]; ok {
				status.Account = profile.LoginName
			}
		}
	}
	status.Devices = make([]TailscaleDevice, 0, len(current.Peer))
	status.ExitNodes = make([]TailscaleDevice, 0, len(current.Peer))
	for _, peer := range current.Peer {
		if peer.ShareeNode {
			continue
		}
		device := tailscaleDeviceOf(peer)
		status.Devices = append(status.Devices, device)
		if peer.ExitNodeOption {
			status.ExitNodes = append(status.ExitNodes, device)
		}
		if peer.ExitNode {
			status.ExitNodeActive = device.Name
		}
	}
	sort.Slice(status.Devices, func(i, j int) bool {
		return status.Devices[i].Name < status.Devices[j].Name
	})
	sort.Slice(status.ExitNodes, func(i, j int) bool {
		return status.ExitNodes[i].Name < status.ExitNodes[j].Name
	})
}

func tailscaleStateOf(raw string) string {
	switch raw {
	case "Running":
		return tailscaleStateRunning
	case "Starting", "NoState":
		return tailscaleStateStarting
	case "NeedsLogin":
		return tailscaleStateNeedsLogin
	case "NeedsMachineAuth":
		return tailscaleStateNeedsApproval
	case "Stopped":
		return tailscaleStateStopped
	case "InUseOtherUser":
		return tailscaleStateError
	case "":
		return tailscaleStateStarting
	default:
		return strings.ToLower(raw)
	}
}

func tailscaleDeviceOf(peer *ipnstate.PeerStatus) TailscaleDevice {
	ips := make([]string, 0, len(peer.TailscaleIPs))
	for _, ip := range peer.TailscaleIPs {
		ips = append(ips, ip.String())
	}
	name := strings.TrimSuffix(peer.DNSName, ".")
	if name == "" {
		name = peer.HostName
	}
	return TailscaleDevice{
		ID:             string(peer.ID),
		Name:           name,
		Hostname:       peer.HostName,
		OS:             peer.OS,
		IPs:            ips,
		Online:         peer.Online,
		Direct:         peer.CurAddr != "",
		Relay:          peer.Relay,
		ExitNode:       peer.ExitNode,
		ExitNodeOption: peer.ExitNodeOption,
	}
}

func tailscaleControlTarget(controlURL string) string {
	raw := strings.TrimSpace(controlURL)
	if raw == "" {
		raw = tailscaleDefaultControl
	}
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Hostname() == "" {
		return "controlplane.tailscale.com:443"
	}
	port := parsed.Port()
	if port == "" {
		port = "443"
		if parsed.Scheme == "http" {
			port = "80"
		}
	}
	return net.JoinHostPort(parsed.Hostname(), port)
}
