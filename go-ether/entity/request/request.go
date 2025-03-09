package request

type AddSigRequest struct {
	Seller    string `json:"seller"`
	TokenId   string `json:"tokenId"`
	Price     string `json:"price"`
	Deadline  string `json:"deadline"`
	Signature string `json:"signature"`
}
