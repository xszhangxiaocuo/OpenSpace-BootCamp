package router

import (
	"github.com/gin-gonic/gin"
)

// Router 路由注册方法接口
type Router interface {
	Route(r *gin.Engine)
}

type RegisterRouter struct {
}

var routers []Router

// InitRouter 批量注册路由
func InitRouter(r *gin.Engine) {
	for _, ro := range routers {
		ro.Route(r)
	}
}

func Register(ro ...Router) {
	routers = append(routers, ro...)
}
