package project

import (
	router "go-ether/api"
	"log"

	"github.com/gin-gonic/gin"
)

// 使用init()通过import调包注册路由
func init() {
	log.Println("init project router")
	router.Register(&RouterProject{})
}

type RouterProject struct {
}

func (rp *RouterProject) Route(r *gin.Engine) {
	h := NewHandlerProject()

	r1 := r.Group("/project")
	r1.POST("/addSig", h.addSig)
	r1.GET("/getListSig", h.getListSig)
	r1.GET("/getSig/:tokenid", h.getSig)
}
