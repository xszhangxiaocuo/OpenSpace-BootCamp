package db

type ListSig struct {
	Id        int    `json:"id" gorm:"primary_key;AUTO_INCREMENT"`
	Seller    string `json:"seller" gorm:"type:varchar(100);not null"`
	TokenId   string `json:"tokenId" gorm:"type:varchar(100);not null"`
	Price     string `json:"price" gorm:"type:varchar(100);not null"`
	Deadline  string `json:"deadline" gorm:"type:varchar(100);not null"`
	Signature string `json:"signature" gorm:"type:varchar(255);not null"`
}
