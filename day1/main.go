package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/rand"
	"strings"
	"time"
)

const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const l = 10

func main() {
	hash("0000")
	hash("00000")
}

func hash(target string) {
	content := "hoshino" + generateRandomString(l)
	result := ""

	startTime := time.Now()
	hash := sha256.New()
	hash.Write([]byte(content))
	bytes := hash.Sum(nil)

	for {
		result = hex.EncodeToString(bytes)
		if strings.HasPrefix(result, target) {
			fmt.Println("Content: ", content)
			fmt.Println("Hash: ", result)
			fmt.Println("Time: ", time.Since(startTime))
			break
		}
		content = "hoshino" + generateRandomString(l)
		hash.Reset()
		hash.Write([]byte(content))
		bytes = hash.Sum(nil)
	}

}

// 生成随机字符串
func generateRandomString(length int) string {
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	result := make([]byte, length)
	for i := range result {
		result[i] = charset[r.Intn(len(charset))]
	}
	return string(result)
}
