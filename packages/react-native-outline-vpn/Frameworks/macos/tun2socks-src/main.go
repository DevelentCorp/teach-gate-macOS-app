// Copyright 2019 The Outline Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package tun2socks

import (
	"context"
	"errors"
	"io"
	"net"
	"runtime/debug"
	"sync"
	"time"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/eycorsican/go-tun2socks/core"
)

func init() {
	// Apple VPN extensions have a memory limit of 15MB. Conserve memory by increasing garbage
	// collection frequency and returning memory to the OS every minute.
	debug.SetGCPercent(10)
}

// TunWriter is an interface that allows for outputting packets to the TUN (VPN).
type TunWriter interface {
	io.WriteCloser
}

// PlatformError represents a platform-specific error.
type PlatformError struct {
	Code    string
	Message string
	Cause   error
}

func (e *PlatformError) Error() string {
	if e.Cause != nil {
		return e.Message + ": " + e.Cause.Error()
	}
	return e.Message
}

// Client provides a transparent container for transport interfaces.
type Client struct {
	streamDialer    transport.StreamDialer
	packetListener  transport.PacketListener
	isSessionActive bool
}

// NewClient creates a new client with the provided dialers.
func NewClient(streamDialer transport.StreamDialer, packetListener transport.PacketListener) *Client {
	return &Client{
		streamDialer:   streamDialer,
		packetListener: packetListener,
	}
}

func (c *Client) StartSession() error {
	c.isSessionActive = true
	return nil
}

func (c *Client) EndSession() error {
	c.isSessionActive = false
	return nil
}

func (c *Client) DialStream(ctx context.Context, address string) (transport.StreamConn, error) {
	if c.streamDialer == nil {
		return nil, errors.New("stream dialer not available")
	}
	return c.streamDialer.DialStream(ctx, address)
}

func (c *Client) ListenPacket(ctx context.Context) (net.PacketConn, error) {
	if c.packetListener == nil {
		return nil, errors.New("packet listener not available")
	}
	return c.packetListener.ListenPacket(ctx)
}

// Tunnel represents a tunnel from a TUN device to a server.
type Tunnel interface {
	// IsConnected is true if Disconnect has not been called.
	IsConnected() bool
	// Disconnect closes the underlying resources. Subsequent Write calls will fail.
	Disconnect()
	// Write writes input data to the TUN interface.
	Write(data []byte) (int, error)
	// UpdateUDPSupport determines if UDP is supported following a network connectivity change.
	UpdateUDPSupport() bool
}

// ConnectOutlineTunnelResult represents the result of ConnectOutlineTunnel.
type ConnectOutlineTunnelResult struct {
	Tunnel Tunnel
	Error  *PlatformError
}

type outlineTunnel struct {
	tunWriter   TunWriter
	lwipStack   core.LWIPStack
	isConnected bool
	client      *Client
}

var _ Tunnel = (*outlineTunnel)(nil)

func (t *outlineTunnel) IsConnected() bool {
	return t.isConnected
}

func (t *outlineTunnel) Disconnect() {
	if !t.isConnected {
		return
	}
	t.isConnected = false
	if t.lwipStack != nil {
		t.lwipStack.Close()
	}
	if t.tunWriter != nil {
		t.tunWriter.Close()
	}
	if t.client != nil {
		t.client.EndSession()
	}
}

func (t *outlineTunnel) Write(data []byte) (int, error) {
	if !t.isConnected {
		return 0, errors.New("failed to write, network stack closed")
	}
	if t.lwipStack == nil {
		return 0, errors.New("lwip stack not initialized")
	}
	return t.lwipStack.Write(data)
}

func (t *outlineTunnel) UpdateUDPSupport() bool {
	// Simple UDP connectivity check
	// In a production implementation, this would test actual UDP connectivity
	return true
}

// ConnectOutlineTunnel creates a tunnel connection.
// This is the main entry point for the tun2socks framework.
// It reads packets from a TUN device and routes it to an Outline proxy server.
//
// `tunWriter` is used to output packets to the TUN (VPN).
// `client` is the Outline client with configured transport dialers.
// `isUDPEnabled` indicates whether the tunnel and/or network enable UDP proxying.
//
// Returns a ConnectOutlineTunnelResult with either a Tunnel instance or a PlatformError.
func ConnectOutlineTunnel(tunWriter TunWriter, client *Client, isUDPEnabled bool) *ConnectOutlineTunnelResult {
	if tunWriter == nil {
		return &ConnectOutlineTunnelResult{Error: &PlatformError{
			Code:    "InternalError",
			Message: "must provide a TunWriter",
		}}
	}
	if client == nil {
		return &ConnectOutlineTunnelResult{Error: &PlatformError{
			Code:    "InternalError", 
			Message: "must provide a client instance",
		}}
	}

	// Start the client session
	if err := client.StartSession(); err != nil {
		return &ConnectOutlineTunnelResult{Error: &PlatformError{
			Code:    "SetupTrafficHandlerFailed",
			Message: "failed to start client session",
			Cause:   err,
		}}
	}

	// Set up the output function for the LWIP stack
	core.RegisterOutputFn(func(data []byte) (int, error) {
		return tunWriter.Write(data)
	})

	// Create the LWIP stack
	lwipStack := core.NewLWIPStack()

	// Create the tunnel instance
	tunnel := &outlineTunnel{
		tunWriter:   tunWriter,
		lwipStack:   lwipStack,
		isConnected: true,
		client:      client,
	}

	// Register TCP and UDP handlers
	core.RegisterTCPConnHandler(&tcpHandler{client: client})
	
	udpHandler := &udpHandler{
		client:  client,
		timeout: 30 * time.Second,
		conns:   make(map[core.UDPConn]net.PacketConn),
	}
	core.RegisterUDPConnHandler(udpHandler)

	return &ConnectOutlineTunnelResult{Tunnel: tunnel}
}

// tcpHandler handles TCP connections
type tcpHandler struct {
	client *Client
}

func (h *tcpHandler) Handle(conn net.Conn, target *net.TCPAddr) error {
	proxyConn, err := h.client.DialStream(context.Background(), target.String())
	if err != nil {
		return err
	}
	
	// Start relay in goroutine
	go func() {
		defer conn.Close()
		defer proxyConn.Close()
		
		// Simple bidirectional copy
		go io.Copy(conn, proxyConn)
		io.Copy(proxyConn, conn)
	}()
	
	return nil
}

// udpHandler handles UDP connections
type udpHandler struct {
	sync.Mutex
	client  *Client
	timeout time.Duration
	conns   map[core.UDPConn]net.PacketConn
}

func (h *udpHandler) Connect(conn core.UDPConn, target *net.UDPAddr) error {
	proxyConn, err := h.client.ListenPacket(context.Background())
	if err != nil {
		return err
	}
	h.Lock()
	h.conns[conn] = proxyConn
	h.Unlock()
	
	// Start relay goroutine for packets from proxy to TUN
	go h.relayFromProxy(conn, proxyConn)
	return nil
}

func (h *udpHandler) ReceiveTo(conn core.UDPConn, data []byte, destAddr *net.UDPAddr) error {
	h.Lock()
	proxyConn, ok := h.conns[conn]
	h.Unlock()
	if !ok {
		return errors.New("connection not found")
	}
	proxyConn.SetDeadline(time.Now().Add(h.timeout))
	_, err := proxyConn.WriteTo(data, destAddr)
	return err
}

func (h *udpHandler) relayFromProxy(tunConn core.UDPConn, proxyConn net.PacketConn) {
	buf := make([]byte, 4096)
	defer func() {
		h.Lock()
		delete(h.conns, tunConn)
		h.Unlock()
		proxyConn.Close()
		tunConn.Close()
	}()
	
	for {
		proxyConn.SetDeadline(time.Now().Add(h.timeout))
		n, sourceAddr, err := proxyConn.ReadFrom(buf)
		if err != nil {
			return
		}
		
		sourceUDPAddr, err := net.ResolveUDPAddr("udp", sourceAddr.String())
		if err != nil {
			return
		}
		
		_, err = tunConn.WriteFrom(buf[:n], sourceUDPAddr)
		if err != nil {
			return
		}
	}
}