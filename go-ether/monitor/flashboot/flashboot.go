package main

import (
	"fmt"
	"log"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
	"github.com/joho/godotenv"
	"github.com/lmittmann/flashbots"
	"github.com/lmittmann/w3"
	"github.com/lmittmann/w3/module/eth"
)

const OpenspaceNFTABI = `[
	{
		"inputs": [],
		"name": "enablePresale",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "presale",
		"outputs": [],
		"stateMutability": "payable",
		"type": "function"
	}
]`

func main() {
	// 1. 加载环境变量
	err := godotenv.Load("../../.env")
	if err != nil {
		log.Println("⚠️ 未找到 .env 文件，将使用系统环境变量")
	}

	// 获取配置项
	contractAddrHex := os.Getenv("OPENSPACE_NFT_ADDR")
	ownerPrivHex := os.Getenv("OWNER_PRIVATE_KEY")
	presalePrivHex := os.Getenv("PRESALE_PRIVATE_KEY")
	rpcWsUrl := os.Getenv("SEPOLIA_RPC_WS_URL")
	rpcHttpUrl := os.Getenv("SEPOLIA_RPC_HTTP_URL")

	if contractAddrHex == "" || presalePrivHex == "" || rpcWsUrl == "" {
		log.Fatal("❌ 缺少必要环境变量（OPENSPACE_NFT_ADDR、PRESALE_PRIVATE_KEY、SEPOLIA_RPC_WS_URL）")
	}

	contractAddr := common.HexToAddress(contractAddrHex)

	// 2. 解析私钥与地址
	ownerKey, _ := crypto.HexToECDSA(strings.TrimPrefix(ownerPrivHex, "0x"))
	ownerAddr := crypto.PubkeyToAddress(ownerKey.PublicKey)

	presaleKey, _ := crypto.HexToECDSA(strings.TrimPrefix(presalePrivHex, "0x"))
	presaleAddr := crypto.PubkeyToAddress(presaleKey.PublicKey)
	signer := types.LatestSigner(params.SepoliaChainConfig)
	log.Println("🔑 Owner 地址:", ownerAddr.Hex())
	log.Println("🔑 Presale 地址:", presaleAddr.Hex())

	// 3. 初始化客户端
	fmt.Println("🚀 连接节点与 Flashbots...")
	nodeClient := w3.MustDial(rpcWsUrl)
	defer nodeClient.Close()

	client := w3.MustDial(rpcHttpUrl)
	defer client.Close()

	fbClient := flashbots.MustDial("https://relay-sepolia.flashbots.net", presaleKey)
	defer fbClient.Close()

	// 4. 监听 pending 池，获取 enablePresale() 交易哈希
	fmt.Println("🎧 正在监听 pending 池中 enablePresale() 交易...")

	enableSelector := crypto.Keccak256([]byte("enablePresale()"))[:4]
	pendingCh := make(chan *types.Transaction, 100)
	sub, err := nodeClient.Subscribe(eth.PendingTransactions(pendingCh))
	if err != nil {
		log.Fatalf("❌ 订阅 pending 池失败: %v", err)
	}
	var enableTx *types.Transaction
	contractABI, err := abi.JSON(strings.NewReader(OpenspaceNFTABI))
	if err != nil {
		log.Fatal("ABI解析失败:", err)
	}
FindEnable:
	for {
		select {
		case tx := <-pendingCh:
			if tx.To() == nil || *tx.To() != contractAddr {
				continue
			}
			// 验证
			from, err := types.Sender(signer, tx)
			if err != nil || from != ownerAddr {
				continue
			}
			// log.Println("🔍 捕获 pending 交易:", tx.Data())
			method, err := contractABI.MethodById(tx.Data()[:4])
			if err != nil {
				fmt.Println("无法识别函数:", err)
				return
			}
			fmt.Println("🔍 调用方法:", method.Name)

			unpackedArgs, err := method.Inputs.Unpack(tx.Data()[4:])
			if err != nil {
				fmt.Println("参数解析失败:", err)
				return
			}

			for i, arg := range unpackedArgs {
				fmt.Printf("参数%d：%v\n", i+1, arg)
			}
			if len(tx.Data()) >= 4 && string(tx.Data()[:4]) == string(enableSelector) {
				enableTx = tx
				break FindEnable
			}
		// case <-time.After(60 * time.Second):
		// 	log.Fatal("❌ 监听超时，未找到 enablePresale() 交易")
		case err := <-sub.Err():
			log.Fatalf("❌ 订阅失败: %v", err)
		}
	}
	sub.Unsubscribe()
	fmt.Println("✅ 捕获 enablePresale() 交易哈希:", enableTx.Hash().Hex())

	// 5. 本地构建 presale(1) 交易
	fmt.Println("🔧 构建 presale(1) 交易...")
	var nonce uint64
	var gasTip, gasFee *big.Int
	var latestBlock *big.Int

	err = client.Call(
		eth.Nonce(presaleAddr, nil).Returns(&nonce),
		eth.GasTipCap().Returns(&gasTip),
		eth.GasPrice().Returns(&gasFee),
		eth.BlockNumber().Returns(&latestBlock),
		// eth.BaseFeePerGas().Returns(&baseFee),
	)
	if err != nil {
		log.Fatalf("❌ 获取交易参数失败: %v", err)
	}

	// 构造 presale(uint256) 方法调用数据
	// presaleSelector := crypto.Keccak256([]byte("presale(uint256)"))[:4]
	// amount := big.NewInt(1)
	// amountPadded := common.LeftPadBytes(amount.Bytes(), 32)
	// data := append(presaleSelector, amountPadded...)
	data := encodePresaleData(big.NewInt(1))

	// tx := &types.DynamicFeeTx{
	// 	ChainID:   big.NewInt(11155111),
	// 	Nonce:     nonce,
	// 	GasTipCap: gasTip,
	// 	GasFeeCap: gasFee,
	// 	Gas:       300000,
	// 	To:        &contractAddr,
	// 	Value:     big.NewInt(1e16), // 0.01 ETH
	// 	Data:      data,
	// }
	tx := &types.DynamicFeeTx{
		ChainID:   big.NewInt(11155111),
		Nonce:     36,
		GasTipCap: gasTip,
		GasFeeCap: gasFee,
		Gas:       300000,
		To:        &contractAddr,
		Value:     big.NewInt(1e16), // 0.01 ETH
		Data:      data,
	}

	// signedTx, err := types.SignTx(tx, signer, presaleKey)
	signedTx := types.MustSignNewTx(presaleKey, signer, tx)
	if err != nil {
		log.Fatalf("❌ presale 交易签名失败: %v", err)
	}
	fmt.Println("✅ 构建完成，本地 presale 交易哈希:", signedTx.Hash().Hex())

	// 6. 构造 Bundle 并提交到 Flashbots
	fmt.Println("📦 构建 Flashbots Bundle 并提交...")
	targetBlock := new(big.Int).Add(latestBlock, w3.Big1)

	var callBundle *flashbots.CallBundleResponse
	err = fbClient.Call(
		flashbots.CallBundle(&flashbots.CallBundleRequest{
			Transactions: types.Transactions{enableTx, signedTx},
			BlockNumber:  targetBlock,
		}).Returns(&callBundle),
	)
	if err != nil {
		log.Fatalf("❌ 模拟 Bundle 失败: %v", err)
	}
	PrintCallBundleResult(callBundle)

	var bundleHash common.Hash
	err = fbClient.Call(
		flashbots.SendBundle(&flashbots.SendBundleRequest{
			Transactions: types.Transactions{enableTx, signedTx},
			BlockNumber:  targetBlock,
		}).Returns(&bundleHash),
	)
	if err != nil {
		log.Fatalf("❌ 提交 Bundle 失败: %v", err)
	}

	fmt.Println("✅ Flashbots Bundle 提交成功:", bundleHash.Hex())

	// 7. 查询 flashbots_getBundleStats 状态
	var stats *flashbots.BundleStatsV2Response
	err = fbClient.Call(
		flashbots.BundleStatsV2(bundleHash, targetBlock).Returns(&stats),
	)
	if err != nil {
		log.Fatalf("❌ 获取 Bundle 状态失败: %v", err)
	}

	fmt.Println("\n📊 Flashbots Bundle 状态信息：")
	fmt.Println("🔸 是否模拟成功:", stats.IsSimulated)
	fmt.Println("🔸 是否高优先级:", stats.IsHighPriority)
	fmt.Println("🔸 模拟时间:", stats.SimulatedAt.UTC())
	fmt.Println("🔸 接收时间:", stats.ReceivedAt.UTC())
	if len(stats.SealedByBuildersAt) > 0 {
		fmt.Println("🔸 被矿工封装的次数:", len(stats.SealedByBuildersAt))
	}
}

// PrintCallBundleResult 打印 Flashbots CallBundle 模拟结果的美观格式
func PrintCallBundleResult(resp *flashbots.CallBundleResponse) {
	fmt.Println("📦 === Flashbots CallBundle 模拟结果 ===")
	fmt.Printf("🔸 BundleHash        : %s\n", resp.BundleHash.Hex())
	fmt.Printf("🔸 状态区块高度     : %s\n", resp.StateBlockNumber.String())
	fmt.Printf("🔸 BundleGasPrice    : %s wei\n", resp.BundleGasPrice.String())
	fmt.Printf("🔸 Gas总消耗         : %d\n", resp.TotalGasUsed)
	fmt.Printf("🔸 矿工收益(CoinbaseDiff): %s wei (~%.6f ETH)\n", resp.CoinbaseDiff.String(), weiToEth(resp.CoinbaseDiff))
	fmt.Printf("🔸 Gas总费用(GasFees): %s wei (~%.6f ETH)\n", resp.GasFees.String(), weiToEth(resp.GasFees))
	fmt.Println()

	// 遍历每笔交易结果
	for i, tx := range resp.Results {
		fmt.Printf("➡️  第 %d 笔交易:\n", i+1)
		fmt.Printf("    🔹 From       : %s\n", tx.FromAddress.Hex())
		fmt.Printf("    🔹 To         : %s\n", tx.ToAddress.Hex())
		fmt.Printf("    🔹 TxHash     : %s\n", tx.TxHash.Hex())
		fmt.Printf("    🔹 GasUsed    : %d\n", tx.GasUsed)
		fmt.Printf("    🔹 GasPrice   : %s wei\n", tx.GasPrice.String())
		fmt.Printf("    🔹 GasFees    : %s wei (~%.6f ETH)\n", tx.GasFees.String(), weiToEth(tx.GasFees))
		fmt.Printf("    🔹 CoinbaseDiff: %s wei (~%.6f ETH)\n", tx.CoinbaseDiff.String(), weiToEth(tx.CoinbaseDiff))
		if tx.Error != nil {
			fmt.Printf("    ❌ Error      : %v\n", tx.Error)
		} else {
			fmt.Printf("    ✅ 是否 Revert : %v\n", tx.Revert != "")
		}
		fmt.Println()
	}
}

// weiToEth 将 wei 转换为 ETH（浮点显示）
func weiToEth(wei *big.Int) float64 {
	eth := new(big.Float).Quo(new(big.Float).SetInt(wei), big.NewFloat(1e18))
	result, _ := eth.Float64()
	return result
}

func encodePresaleData(amount *big.Int) []byte {
	parsedABI, err := abi.JSON(strings.NewReader(OpenspaceNFTABI))
	if err != nil {
		panic(err)
	}
	data, err := parsedABI.Pack("presale", amount)
	log.Printf("🔧 构建 presale(1) 方法调用数据:%x", data)
	if err != nil {
		panic(err)
	}
	return data
}
