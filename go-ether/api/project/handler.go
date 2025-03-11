package project

import (
	"fmt"
	entity "go-ether/entity/db"
	request "go-ether/entity/request"
	db "go-ether/global/database"
	"go-ether/utils"
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
	var oldSig entity.ListSig
	db.DB.Where("token_id = ?", req.TokenId).First(&oldSig)
	if oldSig.Id != 0 {
		db.DB.Model(&oldSig).Updates(sig)
	} else {
		db.DB.Create(&sig)
	}
	utils.SuccessResponse(ctx, nil)
}

// 获取上架NFT列表
func (hp *HandlerProject) getListSig(ctx *gin.Context) {
	var sigs []entity.ListSig
	db.DB.Find(&sigs)
	utils.SuccessResponse(ctx, sigs)
}

// 获取上架NFT签名信息
func (hp *HandlerProject) getSig(ctx *gin.Context) {
	tokenid := ctx.Param("tokenid")
	var sig entity.ListSig
	db.DB.Where("token_id = ?", tokenid).First(&sig)
	utils.SuccessResponse(ctx, sig)
}
