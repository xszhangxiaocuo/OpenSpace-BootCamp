package main

import (
	"context"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
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

	// USDT 合约地址
	usdtAddress := common.HexToAddress("0xdAC17F958D2ee523a2206206994597C13D831ec7")

	// 定义 Transfer 事件的 Topic（事件签名哈希）
	transferTopic := common.HexToHash("0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")

	// 设置日志过滤器，仅监听 USDT 合约的 Transfer 事件
	query := ethereum.FilterQuery{
		Addresses: []common.Address{usdtAddress},
		Topics:    [][]common.Hash{{transferTopic}},
	}
	// 创建日志订阅通道
	logs := make(chan types.Log)

	// 订阅日志
	sub, err := client.SubscribeFilterLogs(context.Background(), query, logs)
	if err != nil {
		log.Fatalf("订阅日志失败: %v", err)
	}
	defer sub.Unsubscribe()

	fmt.Println("开始监听 USDT 转账交易...")

	// 循环接收日志
	for {
		select {
		case err := <-sub.Err():
			log.Fatalf("订阅错误: %v", err)
		case transferLog := <-logs:
			// 解析 Transfer 事件
			if len(transferLog.Topics) == 3 { // Transfer 事件有 3 个 topic
				from := common.BytesToAddress(transferLog.Topics[1].Bytes())
				to := common.BytesToAddress(transferLog.Topics[2].Bytes())
				value := new(big.Int).SetBytes(transferLog.Data)

				// 将最小单位转换为 USDT 可读值（6 位小数）
				valueFloat := new(big.Float).SetInt(value)
				decimals := big.NewFloat(1e6) // USDT 精度为 6
				amount := new(big.Float).Quo(valueFloat, decimals)

				// 格式化输出
				fmt.Printf("在 %d 区块 %s 交易中从 %s 转账 %s USDT 到 %s\n",
					transferLog.BlockNumber,
					transferLog.TxHash.Hex(),
					from.Hex(),
					amount.Text('f', 6), // 保留 6 位小数
					to.Hex())
			}
		}
	}
}
