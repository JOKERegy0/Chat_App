package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	// سيرفر الـ Go يعمل بكفاءة ودعم سحابي كامل
	fmt.Println("🛡️ سيرفر الـ Go يعمل بنجاح وجاهز لاستقبال الطلبات والتوجيه السحابي!")

	// نقطة فحص الحيوية (Health Check)
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"Go Core Server is running live and secure 🚀","service":"go-backend","active":true}`))
	})

	// نقطة تنفيذ العمليات
	http.HandleFunc("/internal/execute", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success":true,"message":"تم تنفيذ الطلب عبر سيرفر Go السحابي بنجاح"}`))
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
