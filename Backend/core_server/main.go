package main

import (
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

// ---------- rate limit: 120 requests per minute for every IP ----------

const maxRequestsPerMinute = 120

var (
	hitsMu sync.Mutex
	hits   = map[string]int{}
)

func allow(ip string) bool {
	hitsMu.Lock()
	defer hitsMu.Unlock()
	hits[ip]++
	return hits[ip] <= maxRequestsPerMinute
}

func resetHitsEvery(d time.Duration) {
	for range time.Tick(d) {
		hitsMu.Lock()
		hits = map[string]int{}
		hitsMu.Unlock()
	}
}

// ---------- client IP: the address the Render proxy added (the last one) ----------
// The first entries of X-Forwarded-For can be written by the client, so they are not trusted.

func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[len(parts)-1])
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// ---------- reverse proxy to an internal service ----------
// fromPrefix is the public path on the gateway, toPrefix is the path on the internal service.

func createProxy(target, fromPrefix, toPrefix, secret string) http.HandlerFunc {
	targetURL, err := url.Parse(target)
	if err != nil || target == "" {
		return func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusServiceUnavailable)
			w.Write([]byte(`{"error":"Service not configured"}`))
		}
	}

	proxy := httputil.NewSingleHostReverseProxy(targetURL)
	defaultDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		defaultDirector(req)
		req.URL.Path = toPrefix + strings.TrimPrefix(req.URL.Path, fromPrefix)
		req.URL.RawPath = ""
		req.Host = targetURL.Host
	}
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		w.Write([]byte(`{"error":"Upstream unavailable"}`))
	}

	return func(w http.ResponseWriter, r *http.Request) {
		ip := clientIP(r)
		if !allow(ip) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error":"Too many requests"}`))
			return
		}

		r.Header.Del("X-Forwarded-For")
		r.Header.Del("X-Client-Ip")
		r.Header.Set("X-Client-Ip", ip)
		r.Header.Set("X-Forwarded-By", "kiura-go-gateway")
		r.Header.Set("X-Service-Secret", secret)

		proxy.ServeHTTP(w, r)
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// the shared secret must come from the environment, never from the code
	internalServiceSecret := os.Getenv("INTERNAL_SERVICE_SECRET")
	if internalServiceSecret == "" {
		log.Fatal("Missing INTERNAL_SERVICE_SECRET environment variable")
	}

	// internal service addresses (set them in the Render environment)
	internalAuthServer := os.Getenv("INTERNAL_AUTH_SERVER")
	internalSecurityServer := os.Getenv("INTERNAL_SECURITY_SERVER")
	internalMediaServer := os.Getenv("INTERNAL_MEDIA_SERVER")
	internalDailyServer := os.Getenv("INTERNAL_DAILY_SERVER")

	go resetHitsEvery(time.Minute)

	mux := http.NewServeMux()

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ONLINE","service":"kiura-gateway-go"}`))
	})

	// public path on the gateway  ->  path on the internal service
	mux.HandleFunc("/api/auth/", createProxy(internalAuthServer, "/api/auth", "/api/v1/auth", internalServiceSecret))
	mux.HandleFunc("/api/security/", createProxy(internalSecurityServer, "/api/security", "/api/v1/security", internalServiceSecret))
	mux.HandleFunc("/api/media/", createProxy(internalMediaServer, "/api/media", "/api/v1/media", internalServiceSecret))
	mux.HandleFunc("/api/daily/", createProxy(internalDailyServer, "/api/daily", "/api/requests", internalServiceSecret))

	log.Printf("KIURA Go gateway is running on port %s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("Go server error: %v", err)
	}
}
