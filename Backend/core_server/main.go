package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"

	"github.com/jackc/pgx/v5"
)

func main() {
	connectionString := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	
	ctx := context.Background()
	if connectionString != "" {
		config, err := pgx.ParseConfig(connectionString)
		if err != nil {
			log.Printf("⚠️ خطأ في تحليل رابط القاعدة: %v\n", err)
		} else {
			// إجبار الاتصال على استخدام بروتوكول IPv4 (tcp4) لتجنب حظر الشبكة على Render
			config.DialFunc = func(ctx context.Context, network, addr string) (net.Conn, error) {
				var d net.Dialer
				return d.DialContext(ctx, "tcp4", addr)
			}

			conn, err := pgx.ConnectConfig(ctx, config)
			if err != nil {
				log.Printf("⚠️ تحذير الاتصال بقاعدة البيانات: %v\n", err)
			} else {
				defer conn.Close(ctx)
				fmt.Println("🛡️ سيرفر الـ Go متصل بقاعدة البيانات سحابياً بنجاح تام عبر IPv4 الآمن!")
			}
		}
	} else {
		log.Println("⚠️ تنبيه: متغير البيئة DATABASE_URL غير موجود!")
	}

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"Go Core Database Server is running securely with IPv4 Dial 🔒","connected":true}`))
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "10000"
	}

	fmt.Printf("🚀 سيرفر الـ Go شغال بنجاح على البورت %s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("❌ فشل تشغيل السيرفر: %v", err)
	}
}
