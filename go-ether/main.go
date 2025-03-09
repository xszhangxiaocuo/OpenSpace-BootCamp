package main

import (
	router "go-ether/api"
	_ "go-ether/api/api"
	"go-ether/db"
	"net/http"

	"github.com/gin-gonic/gin"
)

// 自定义 CORS 中间件
func CorsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*") // 允许所有来源
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		// 处理预检请求
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

func main() {
	r := gin.Default()
	r.Use(CorsMiddleware())
	db.InitDB()
	router.InitRouter(r)
	r.Run(":8078")
}
