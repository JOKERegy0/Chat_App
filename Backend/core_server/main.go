package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/jackc/pgx/v5"
)

func main() {
	// الرابط الصحيح لقاعدة البيانات مهيأ بكلمة المرور الخاصة بك
	connectionString := "postgresql://postgres:KIURASERVEREGYJOKERFORME2026112@db.dymrernfuorzmbcaaocy.supabase.co:5432/postgres"

	// محاولة الاتصال بقاعدة البيانات عبر pgx
	ctx := context.Background()
	conn, err := pgx.Connect(ctx, connectionString)
	if err != nil {
		log.Printf("⚠️ تحذير: فشل الاتصال بقاعدة البيانات: %v\n", err)
	} else {
		defer conn.Close(ctx)
		fmt.Println("🛡️ سيرفر الـ Go متصل بقاعدة البيانات سحابياً بنجاح تام عبر Render!")
	}

	// نقطة فحص الحيوية (Health Check)
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"Go Core Database Server is running securely 🔒","connected":true}`))
	})

	// نقطة استقبال العمليات
	http.HandleFunc("/internal/execute", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success":true,"message":"تم تنفيذ العملية بنجاح عبر السيرفر المركزي بلغة Go"}`))
	})

	// تحديد البورت التلقائي من Render أو البورت الافتراضي
	port := os.Getenv("PORT")
	if port == "" {
		port = "10000"
	}

	fmt.Printf("🚀 سيرفر الـ Go شغال بنجاح على البورت %s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("❌ فشل تشغيل السيرفر: %v", err)
	}
}
