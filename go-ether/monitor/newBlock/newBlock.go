package main

import (
	"context"
	"fmt"
	"log"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
)

func main() {
	// 连接到以太坊节点的 WebSocket 端点
	client, err := ethclient.Dial("wss://mainnet.gateway.tenderly.co")
	if err != nil {
		log.Fatalf("无法连接到以太坊节点: %v", err)
	}
	defer client.Close()

	// 创建一个通道用于接收新区块头
	headers := make(chan *types.Header)
	defer close(headers)

	// 订阅新区块头
	sub, err := client.SubscribeNewHead(context.Background(), headers)
	if err != nil {
		log.Fatalf("订阅新区块失败: %v", err)
	}
	defer sub.Unsubscribe()

	fmt.Println("开始监听新区块...")

	// 循环接收新区块信息
	for {
		select {
		case err := <-sub.Err():
			log.Fatalf("订阅错误: %v", err)
		case header := <-headers:
			// 打印区块高度和哈希值
			fmt.Printf("新区块: 高度 = %d, 哈希值 = %s\n", header.Number.Uint64(), header.Hash().Hex())
		}
	}
}
