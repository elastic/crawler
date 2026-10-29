// Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
// or more contributor license agreements. Licensed under the Elastic License 2.0;
// you may not use this file except in compliance with the Elastic License 2.0.

// Wire-level check of `bin/crawler agent` against the Elastic Agent client stub server
// (github.com/elastic/elastic-agent-client), over mutual TLS on TCP like the real agent.
//
// Usage: cd script/agent/harness && go run . <crawler checkout> <log file for crawler output>
package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"math/big"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"sync"
	"time"

	"github.com/elastic/elastic-agent-client/v7/pkg/client/mock"
	"github.com/elastic/elastic-agent-client/v7/pkg/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	gproto "google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/structpb"
)

type certs struct {
	caPEM, clientCert, clientKey []byte
	serverTLS                    tls.Certificate
}

func makeCerts() certs {
	caKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	caTpl := &x509.Certificate{
		SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "harness-ca"},
		NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(24 * time.Hour),
		IsCA: true, KeyUsage: x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature, BasicConstraintsValid: true,
	}
	caDER, _ := x509.CreateCertificate(rand.Reader, caTpl, caTpl, &caKey.PublicKey, caKey)
	caCert, _ := x509.ParseCertificate(caDER)
	leaf := func(cn string, serial int64, server bool) ([]byte, []byte) {
		key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
		tpl := &x509.Certificate{
			SerialNumber: big.NewInt(serial), Subject: pkix.Name{CommonName: cn},
			NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(24 * time.Hour),
			KeyUsage: x509.KeyUsageDigitalSignature,
		}
		if server {
			tpl.ExtKeyUsage = []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}
			tpl.DNSNames = []string{"localhost"}
			tpl.IPAddresses = []net.IP{net.ParseIP("127.0.0.1")}
		} else {
			tpl.ExtKeyUsage = []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth}
		}
		der, _ := x509.CreateCertificate(rand.Reader, tpl, caCert, &key.PublicKey, caKey)
		keyDER, _ := x509.MarshalECPrivateKey(key)
		return pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}),
			pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: keyDER})
	}
	sc, sk := leaf("localhost", 2, true)
	cc, ck := leaf("crawler", 3, false)
	serverTLS, _ := tls.X509KeyPair(sc, sk)
	return certs{
		caPEM:      pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: caDER}),
		clientCert: cc, clientKey: ck, serverTLS: serverTLS,
	}
}

func mustStruct(v map[string]interface{}) *structpb.Struct {
	s, err := structpb.NewStruct(v)
	if err != nil {
		panic(err)
	}
	return s
}

type state struct {
	mu       sync.Mutex
	units    map[string]*proto.UnitObserved
	checkins int
	stop     bool
}

func (s *state) snapshot() map[string]*proto.UnitObserved {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := map[string]*proto.UnitObserved{}
	for k, v := range s.units {
		out[k] = v
	}
	return out
}

func waitFor(desc string, timeout time.Duration, cond func() bool) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if cond() {
			fmt.Printf("OK   %s\n", desc)
			return
		}
		time.Sleep(200 * time.Millisecond)
	}
	fmt.Printf("FAIL %s (timeout)\n", desc)
	os.Exit(1)
}

func main() {
	if len(os.Args) < 3 {
		fmt.Println("usage: go run . <crawler checkout> <crawler log file>")
		os.Exit(2)
	}
	crawlerHome := os.Args[1]
	c := makeCerts()
	caPool := x509.NewCertPool()
	caPool.AppendCertsFromPEM(c.caPEM)

	site := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/":
			fmt.Fprint(w, `<html><head><title>Harness home</title></head><body><p>hello</p><a href="/about">about</a></body></html>`)
		case "/about":
			fmt.Fprint(w, `<html><head><title>About</title></head><body><p>about page</p></body></html>`)
		default:
			http.NotFound(w, r)
		}
	}))
	defer site.Close()

	st := &state{units: map[string]*proto.UnitObserved{}}
	inputCfg := mustStruct(map[string]interface{}{
		"id": "crawler-harness", "type": "crawler", "name": "harness", "revision": 1,
		"domains":     []interface{}{map[string]interface{}{"url": site.URL}},
		"output_sink": "console", "log_level": "info", "max_crawl_depth": 2,
	})
	outputCfg := mustStruct(map[string]interface{}{
		"type": "elasticsearch", "hosts": []interface{}{"http://127.0.0.1:9200"}, "api_key": "id:key",
	})

	srv := &mock.StubServerV2{
		ActionsChan: make(chan *mock.PerformAction, 10),
		SentActions: map[string]*mock.PerformAction{},
		ActionImpl:  func(*proto.ActionResponse) error { return nil },
	}
	srv.CheckinV2Impl = func(observed *proto.CheckinObserved) *proto.CheckinExpected {
		st.mu.Lock()
		st.checkins++
		for _, u := range observed.Units {
			st.units[u.Id] = u
		}
		stop := st.stop
		st.mu.Unlock()
		expectedState := proto.State_HEALTHY
		if stop {
			expectedState = proto.State_STOPPED
		}
		return &proto.CheckinExpected{
			AgentInfo:    &proto.AgentInfo{Id: "harness-agent", Version: "9.2.0"},
			ComponentIdx: 1,
			Units: []*proto.UnitExpected{
				{Id: "crawler-unit", Type: proto.UnitType_INPUT, State: expectedState, ConfigStateIdx: 1, LogLevel: proto.UnitLogLevel_INFO,
					Config: &proto.UnitExpectedConfig{Id: "crawler-harness", Type: "crawler", Name: "harness", Source: inputCfg}},
				{Id: "es-unit", Type: proto.UnitType_OUTPUT, State: expectedState, ConfigStateIdx: 1, LogLevel: proto.UnitLogLevel_INFO,
					Config: &proto.UnitExpectedConfig{Id: "default", Type: "elasticsearch", Source: outputCfg}},
			},
		}
	}
	tlsCfg := &tls.Config{
		Certificates: []tls.Certificate{c.serverTLS}, ClientAuth: tls.RequireAndVerifyClientCert,
		ClientCAs: caPool, MinVersion: tls.VersionTLS12,
	}
	if err := srv.Start(grpc.Creds(credentials.NewTLS(tlsCfg))); err != nil {
		panic(err)
	}
	defer srv.Stop()
	fmt.Printf("stub agent listening on %s (mTLS)\n", srv.GetTarget())

	info := &proto.StartUpInfo{
		Addr: fmt.Sprintf("127.0.0.1:%d", srv.Port), ServerName: "localhost", Token: "harness-token",
		CaCert: c.caPEM, PeerCert: c.clientCert, PeerKey: c.clientKey,
		Services: []proto.ConnInfoServices{proto.ConnInfoServices_CheckinV2, proto.ConnInfoServices_Store,
			proto.ConnInfoServices_Artifact, proto.ConnInfoServices_Log},
		Supports:       []proto.ConnectionSupports{proto.ConnectionSupports_CheckinChunking},
		MaxMessageSize: 100 * 1024 * 1024,
		AgentInfo:      &proto.AgentInfo{Id: "harness-agent", Version: "9.2.0"},
	}
	infoBytes, _ := gproto.Marshal(info)

	logFile, err := os.Create(os.Args[2])
	if err != nil {
		panic(err)
	}
	cmd := exec.Command("bin/crawler", "agent", "--checkin-interval=1")
	cmd.Dir = crawlerHome
	cmd.Stdout, cmd.Stderr = logFile, logFile
	stdin, _ := cmd.StdinPipe()
	if err := cmd.Start(); err != nil {
		panic(err)
	}
	_, _ = stdin.Write(infoBytes)
	stdin.Close()
	defer cmd.Process.Kill()

	healthy := func(id string) bool {
		u := st.snapshot()[id]
		return u != nil && u.State == proto.State_HEALTHY && u.ConfigStateIdx == 1
	}
	waitFor("crawler checked in over mTLS gRPC", 90*time.Second, func() bool {
		st.mu.Lock()
		defer st.mu.Unlock()
		return st.checkins > 0
	})
	waitFor("input unit HEALTHY with config idx 1", 30*time.Second, func() bool { return healthy("crawler-unit") })
	waitFor("output unit HEALTHY", 30*time.Second, func() bool { return healthy("es-unit") })
	fmt.Printf("     input message: %q\n", st.snapshot()["crawler-unit"].Message)

	res, err := srv.PerformAction("crawler-unit", proto.UnitType_INPUT, "crawl", map[string]interface{}{})
	if err != nil {
		fmt.Printf("FAIL crawl action: %v\n", err)
		os.Exit(1)
	}
	b, _ := json.Marshal(res)
	fmt.Printf("OK   crawl action accepted: %s\n", b)

	// Fleet INPUT_ACTION shape: named after the input type, command in data.action
	_, err = srv.PerformAction("crawler-unit", proto.UnitType_INPUT, "crawler", map[string]interface{}{
		"type": "INPUT_ACTION", "input_type": "crawler", "data": map[string]interface{}{"action": "crawl"},
	})
	if err == nil {
		fmt.Println("FAIL second crawl should be rejected while one is running")
		os.Exit(1)
	}
	fmt.Printf("OK   concurrent crawl rejected: %v\n", err)

	crawlStatus := func() string {
		u := st.snapshot()["crawler-unit"]
		if u == nil || u.Payload == nil {
			return ""
		}
		crawl, ok := u.Payload.AsMap()["crawl"].(map[string]interface{})
		if !ok {
			return ""
		}
		s, _ := crawl["status"].(string)
		return s
	}
	waitFor("crawl reported as success in unit payload", 120*time.Second, func() bool { return crawlStatus() == "success" })
	fmt.Printf("     payload: %v\n", st.snapshot()["crawler-unit"].Payload.AsMap()["crawl"])

	status, err := srv.PerformAction("crawler-unit", proto.UnitType_INPUT, "status", nil)
	if err != nil {
		fmt.Printf("FAIL status action: %v\n", err)
		os.Exit(1)
	}
	b, _ = json.Marshal(status)
	fmt.Printf("OK   status action: %s\n", b)

	st.mu.Lock()
	st.stop = true
	st.mu.Unlock()
	waitFor("units STOPPED after agent expects STOPPED", 30*time.Second, func() bool {
		s := st.snapshot()
		return s["crawler-unit"] != nil && s["crawler-unit"].State == proto.State_STOPPED &&
			s["es-unit"] != nil && s["es-unit"].State == proto.State_STOPPED
	})

	_ = cmd.Process.Signal(os.Interrupt)
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		fmt.Printf("OK   process exited on SIGINT (err=%v)\n", err)
	case <-time.After(40 * time.Second):
		fmt.Println("FAIL process did not exit on SIGINT")
		os.Exit(1)
	}
	fmt.Println("PASS")
}
