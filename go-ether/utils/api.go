package utils

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// API 统一响应结构
type ApiResponse struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// 统一返回成功数据
func SuccessResponse(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, ApiResponse{
		Code:    200,
		Message: "Success",
		Data:    data,
	})
}

// 统一返回错误信息
func ErrorResponse(c *gin.Context, code int, message string) {
	c.JSON(code, ApiResponse{
		Code:    code,
		Message: message,
	})
}
