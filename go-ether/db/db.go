package db

import (
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	entity "go-ether/entity/db"
)

var db *gorm.DB

// 初始化gorm
func InitDB() {
	// 连接postgres数据库
	dsn := "host=127.0.0.1 port=5432 user=postgres password=hoshino6659644 dbname=openspace sslmode=disable TimeZone=Asia/Shanghai"
	var err error
	db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		panic(err)
	}
	if db == nil {
		panic("_db is nil")
	}
	log.Println("connect db success:", db)
	/**
	 * 自动迁移表结构
	 * 会自动创建表，不存在的字段会自动添加
	 * 会自动更新表结构，字段类型发生变化会自动修改
	 */
	if err = db.AutoMigrate(&entity.ListSig{}); err != nil {
		panic(err)
	}
}

func GetDB() *gorm.DB {
	return db
}
