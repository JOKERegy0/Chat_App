package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	_ "github.com/lib/pq"
)

var DB *sql.DB

func InitDB() {
	connStr := os.Getenv("DATABASE_URL")
	if connStr == "" {
		connStr = "postgres://postgres:KIURASERVEREGYJOKERFORME2026112@db.dymrernfuorzmbcaaocy.supabase.co:5432/postgres?sslmode=disable"
	}
	
	var err error
	DB, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("خطأ في الاتصال بقاعدة البيانات: %v", err)
	}

	err = DB.Ping()
	if err != nil {
		log.Fatalf("قاعدة البيانات لا تستجيب: %v", err)
	}

	fmt.Println("السيرفر المركزي متصل بقاعدة البيانات سحابياً بنجاح 🛡️🔥")
}

func main() {
	InitDB()

	app := fiber.New()

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status": "Core Database Server is running securely 🔒",
		})
	})

	app.Post("/internal/execute", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"success": true,
			"message": "تم تنفيذ العملية بنجاح عبر السيرفر المركزي",
		})
	})

	log.Fatal(app.Listen(":5001"))
}