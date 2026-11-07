package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
)

// هيكل الرد السريع للعميل
type Response struct {
    Status    string `json:"status"`
    Core      string `json:"core"`
    FastSpeed bool   `json:"fast_speed"`
}

func main() {
    // نقطة فحص الحيوية والتأكيد أن سيرفر Go شغال كأداء أساسي
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        
        response := Response{
            Status:    "Active and running securely 🚀",
            Core:      "Go Primary Gateway (KIURA)",
            FastSpeed: true,
        }
        json.NewEncoder(encodeResponse(w, response)) // استجابة سريعة
    })

    // نقطة استعلام واستقبال العمليات الأساسية بسرعة فائقة
    http.HandleFunc("/api/core/execute", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        
        w.Write([]byte(`{
            "success": true,
            "message": "تم تنفيذ الطلب بنجاح عبر سيرفر Go الأساسي وبأقصى سرعة ⚡",
            "server": "Go High-Performance Core"
        }`))
    })

    port := os.Getenv("PORT")
    if port == "" {
        port = "8080" // البورت الافتراضي لو مش محدد
    }

    fmt.Printf("🚀 KIURA Go Primary Core running smoothly on port %s\n", port)
    if err := http.ListenAndServe(":"+port, nil); err != nil {
        log.Fatalf("❌ Server failed to start: %v", err)
    }
}

// دالة مساعدة لتسهيل كتابة الاستجابة
func encodeResponse(w http.ResponseWriter, v interface{}) http.ResponseWriter {
    json.NewEncoder(w).Encode(v)
    return w
}
