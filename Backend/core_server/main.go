package main

import (
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"time"
)

// دالة مساعدة لجلب متغيرات البيئة أو القيم الافتراضية محلياً
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}

// دالة إنشاء الـ Reverse Proxy الموجه للسيرفرات الداخلية مع تمرير الآيبي
func createProxy(target string) http.HandlerFunc {
	targetUrl, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(targetUrl)

	return func(w http.ResponseWriter, r *http.Request) {
		clientIP := r.Header.Get("X-Forwarded-For")
		if clientIP == "" {
			clientIP = r.RemoteAddr
		}
		
		log.Printf("⚡ [Go Proxy] Routing %s %s ➔ Target: %s", r.Method, r.URL.Path, target)

		r.Header.Set("X-Client-Ip", clientIP)
		r.Header.Set("X-Forwarded-By", "kiura-go-dmz-gateway")
		r.Host = targetUrl.Host
		
		proxy.ServeHTTP(w, r)
	}
}

func main() {
	port := getEnv("PORT", "8080")

	// 🌐 عناوين السيرفرات الداخلية (تأخذ من متغيرات البيئة أو الـ Fallback محلياً)
	internalAuthServer     := getEnv("INTERNAL_AUTH_SERVER", "http://localhost:5001")
	internalChatServer     := getEnv("INTERNAL_CHAT_SERVER", "http://localhost:5002")         // سيرفر المراسلة
	internalSecurityServer := getEnv("INTERNAL_SECURITY_SERVER", "http://localhost:5003") // سيرفر الأمان
	internalMediaServer    := getEnv("INTERNAL_MEDIA_SERVER", "http://localhost:5004")       // سيرفر الوسائط
	internalDailyServer    := getEnv("INTERNAL_DAILY_SERVER", "http://localhost:5005")       // سيرفر الطلبات اليومية

	// 🔑 مفتاح الأمان الموحد والمتفق عليه
	internalServiceSecret  := getEnv("INTERNAL_SERVICE_SECRET", "KIURA_INTERNAL_SERVICE_KEY_2026")

	// 1. 🚀 هاندشيك الإقلاع وفحص الأمان لـ Go Gateway
	http.HandleFunc("/api/core/handshake", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		securityKey := r.Header.Get("X-Security-Key")
		if securityKey == "" {
			securityKey = r.URL.Query().Get("securityKey")
		}

		if securityKey != internalServiceSecret {
			log.Printf("🚨 Unauthorized Go Handshake Attempt")
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusForbidden)
			w.Writer.Write([]byte(`{"status": "Rejected", "error": "Invalid Security Key in Go Gateway ❌"}`))
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Writer.Write([]byte(`{
			"status": "Success",
			"message": "Secure Go DMZ Handshake Passed ⚡",
			"gateway": "main.go (Go High-Speed Gateway)",
			"timestamp": "` + time.Now().Format(time.RFC3339) + `"
		}`))
	}))

	// 2. 🔄 توجيه طلبات المصادقة (Auth)
	http.HandleFunc("/api/auth/", createProxy(internalAuthServer))

	// 3. 💬 توجيه طلبات الشات والمراسلة (Chat)
	http.HandleFunc("/api/chat/", createProxy(internalChatServer))

	// 4. 🔒 توجيه طلبات الحماية والفحص (Security)
	http.HandleFunc("/api/security/", createProxy(internalSecurityServer))

	// 5. 📁 توجيه طلبات الوسائط والملفات (Media)
	http.HandleFunc("/api/media/", createProxy(internalMediaServer))

	// 6. 📅 توجيه الطلبات والمهام اليومية (Daily Requests)
	http.HandleFunc("/api/daily/", createProxy(internalDailyServer))

	log.Printf("🚀 main.go (Go High-Performance DMZ Gateway) is active and running on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("❌ Go Server Error: %v", err)
	}
}
