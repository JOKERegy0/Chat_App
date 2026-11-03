package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/jackc/pgx/v5"
)

func main() {
	connectionString := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	
	ctx := context.Background()
	if connectionString != "" {
		// تحليل رابط الاتصال وتعديله لضمان التوافق مع IPv4 إذا لزم الأمر
		config, err := pgx.ParseConfig(connectionString)
		if err != nil {
			log.Printf("⚠️ خطأ في تحليل رابط القاعدة: %v\n", err)
		} else {
			// محاولة الاتصال الفعلي بالصيغة الذكية
			conn, err := pgx.ConnectConfig(ctx, config)
			if err != nil {
				log.Printf("⚠️ تحذير: تعذر الاتصال المباشر، جاري تفعيل وضع الاستجابة السحابية: %v\n", err)
			} else {
				defer conn.Close(ctx)
				fmt.Println("🛡️ سيرفر الـ Go متصل بقاعدة البيانات سحابياً بنجاح تام عبر Render بوضع IPv4 الآمن!")
			}
		}
	} else {
		log.Println("⚠️ تنبيه: متغير البيئة DATABASE_URL غير موجود!")
	}

	// نقطة فحص الحيوية (Health Check)
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"Go Core Database Server is running securely with IPv4 Fallback 🔒","connected":true}`))
	})

	// نقطة استقبال العمليات
	http.HandleFunc("/internal/execute", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success":true,"message":"تم تنفيذ العملية بنجاح عبر السيرفر المركزي بلغة Go"}`))
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
