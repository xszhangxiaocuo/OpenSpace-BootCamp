// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
编写一个 Bank 合约，实现功能：

可以通过 Metamask 等钱包直接给 Bank 合约地址存款
在 Bank 合约记录每个地址的存款金额
编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
用数组记录存款金额的前 3 名用户
*/

import "./IBank.sol";

//0xDc03C6B15cF5c4012CAaA586ee5f9bd6961B024a
contract Bank is IBank {
    // 部署合约的账户才能提现
    address public owner;
    mapping(address => uint256) public balanceMap;
    address[3] public rank;

    constructor() {
        owner = msg.sender;
    }

    // 接收eth时更新rank
    receive() external payable virtual {
        balanceMap[msg.sender] += msg.value;
        if (balanceMap[msg.sender] > balanceMap[rank[2]]) {
            updateRank();
        }
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == owner, unicode"账户无提现权限");
        require(address(this).balance >= amount, unicode"合约账户余额不足");

        (bool success,)= payable(owner).call{value: amount}("");
        require(success,"withdraw failed");
    }

    function getRank() external view returns (address[3] memory) {
        return rank;
    }

    function getBalance() external view returns (uint256) {
        return balanceMap[msg.sender];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function updateRank() internal {
        address addr = msg.sender;
        uint256 balance = balanceMap[addr];
        for (uint8 i = 0; i < 3; i++) {
            if (balance >= balanceMap[rank[i]]) {
                if (rank[i] == addr) {
                    break;
                }
                for (uint8 j = 2; j > i; j--) {
                    rank[j] = rank[j - 1];
                }
                rank[i] = msg.sender;
                break;
            }
        }
    }
}
