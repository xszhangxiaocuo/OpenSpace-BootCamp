package main

import (
	"context"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"golang.org/x/crypto/sha3"
)

type LockInfo struct {
	User      common.Address
	StartTime uint64
	Amount    *big.Int
}

func main() {
	rpcURL := "https://ethereum-sepolia.rpc.subquery.network/public"

	contractAddress := common.HexToAddress("0x12E5fe7021a48705B2AeDaA31F203B09A3ADb08f")

	// 连接到 Sepolia 网络
	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		log.Fatalf("Failed to connect to Sepolia: %v", err)
	}
	defer client.Close()

	// 获取数组长度 (存储在 slot 0)
	arrayLength, err := getArrayLength(client, contractAddress)
	if err != nil {
		log.Fatalf("Failed to get array length: %v", err)
	}

	fmt.Printf("Found %d locks in the array\n", arrayLength)

	// 遍历并读取每个元素
	locks, err := readLocks(client, contractAddress, arrayLength)
	if err != nil {
		log.Fatalf("Failed to read locks: %v", err)
	}

	for i, lock := range locks {
		fmt.Printf("locks[%d]: user: %s, startTime: %d, amount: %s\n",
			i,
			lock.User.Hex(),
			lock.StartTime,
			lock.Amount.String(),
		)
	}
}

// 获取数组长度
func getArrayLength(client *ethclient.Client, contract common.Address) (uint64, error) {
	slot := common.BigToHash(big.NewInt(0)) // _locks 数组的基槽
	data, err := client.StorageAt(context.Background(), contract, slot, nil)
	if err != nil {
		return 0, err
	}
	length := new(big.Int).SetBytes(data)
	return length.Uint64(), nil
}

// 读取所有 lock 数据
func readLocks(client *ethclient.Client, contract common.Address, length uint64) ([]LockInfo, error) {
	locks := make([]LockInfo, length)

	// 计算数组的基地址
	baseSlot := make([]byte, 32) // slot 0
	baseSlotHash := common.BytesToHash(keccak256(baseSlot))
	log.Println("Base slot hash:", baseSlotHash)

	for i := uint64(0); i < length; i++ {
		// 每个 LockInfo 占用 2 个 slot
		// slot = keccak256(baseSlot) + i * 2
		slot := new(big.Int).Add(
			new(big.Int).SetBytes(baseSlotHash[:]),
			big.NewInt(int64(i*2)),
		)
		log.Println("Reading slot:", slot)
		// 读取 user 和 startTime (slot n)
		userSlot := common.BigToHash(slot)
		userData, err := client.StorageAt(context.Background(), contract, userSlot, nil)
		if err != nil {
			return nil, err
		}

		// 读取 amount (slot n+1)
		dataSlot := common.BigToHash(new(big.Int).Add(slot, big.NewInt(1)))
		slotData, err := client.StorageAt(context.Background(), contract, dataSlot, nil)
		if err != nil {
			return nil, err
		}

		// 解析数据
		lock := LockInfo{
			User:      common.BytesToAddress(userData[12:]),           // 地址占后20字节
			StartTime: new(big.Int).SetBytes(userData[4:12]).Uint64(), // 时间戳占地址前8字节
			Amount:    new(big.Int).SetBytes(slotData),                // 金额占全部32字节
		}

		locks[i] = lock
	}

	return locks, nil
}

// keccak256 实现
func keccak256(data []byte) []byte {
	hasher := sha3.NewLegacyKeccak256()
	hasher.Write(data)
	baseSlot := hasher.Sum(nil)
	base := new(big.Int).SetBytes(baseSlot)
	return base.Bytes()
}
