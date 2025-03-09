package project

import (
	"fmt"
	"go-ether/db"
	entity "go-ether/entity/db"
	request "go-ether/entity/request"
	"go-ether/utils"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

// 业务路由处理函数
type HandlerProject struct {
}

func NewHandlerProject() *HandlerProject {
	return &HandlerProject{}
}

// 新增上架NFT离线签名信息
func (hp *HandlerProject) addSig(ctx *gin.Context) {
	_db := db.GetDB()
	var req request.AddSigRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, fmt.Sprintf("参数错误: %v", err))
		return
	}

	sig := entity.ListSig{
		Seller:    req.Seller,
		TokenId:   req.TokenId,
		Price:     req.Price,
		Deadline:  req.Deadline,
		Signature: req.Signature,
	}
	// 如果tokenid对应的签名已经存在就进行更新
	if _db == nil {
		log.Println("db is nil")
	}
	var oldSig entity.ListSig
	_db.Where("token_id = ?", req.TokenId).First(&oldSig)
	if oldSig.Id != 0 {
		_db.Model(&oldSig).Updates(sig)
	} else {
		_db.Create(&sig)
	}
	utils.SuccessResponse(ctx, nil)
}

// 获取上架NFT列表
func (hp *HandlerProject) getListSig(ctx *gin.Context) {
	_db := db.GetDB()
	var sigs []entity.ListSig
	_db.Find(&sigs)
	utils.SuccessResponse(ctx, sigs)
}

// 获取上架NFT签名信息
func (hp *HandlerProject) getSig(ctx *gin.Context) {
	_db := db.GetDB()
	tokenid := ctx.Param("tokenid")
	var sig entity.ListSig
	_db.Where("token_id = ?", tokenid).First(&sig)
	utils.SuccessResponse(ctx, sig)
}
