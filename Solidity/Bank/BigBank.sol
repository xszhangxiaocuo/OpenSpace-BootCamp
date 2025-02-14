// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
在 该挑战 的 Bank 合约基础之上，编写 IBank 接口及BigBank 合约，使其满足 Bank 实现 IBank， BigBank 继承自 Bank ， 同时 BigBank 有附加要求：

要求存款金额 >0.001 ether（用modifier权限控制）
BigBank 合约支持转移管理员
编写一个 Admin 合约， Admin 合约有自己的 Owner ，同时有一个取款函数 adminWithdraw(IBank bank) , adminWithdraw 中会调用 IBank 接口的 withdraw 方法从而把 bank 合约内的资金转移到 Admin 合约地址。

BigBank 和 Admin 合约 部署后，把 BigBank 的管理员转移给 Admin 合约地址，模拟几个用户的存款，然后

Admin 合约的Owner地址调用 adminWithdraw(IBank bank) 把 BigBank 的资金转移到 Admin 地址。
*/

import "Bank/bank.sol";
import "Bank/IBank.sol";

contract BigBank is Bank {
    modifier onlyEnoughAmount(uint256 amount) {
        require(
            amount > 0.001 ether,
            unicode"存款金额必须大于0.001 ether"
        );
        _;
    }
    modifier onlyOwner(address addr) {
        require(addr == owner, unicode"无管理员权限");
        _;
    }

    receive() onlyEnoughAmount(msg.value) external payable override {
        balanceMap[msg.sender] += msg.value;
        if (balanceMap[msg.sender] > balanceMap[rank[2]]) {
            updateRank();
        }
    }

    function transferOwner(address addr) onlyOwner(msg.sender) external {
        owner = addr;
    }
}

contract Admin {
    address public owner;
    constructor() {
        owner = msg.sender;
    }

    receive() external payable { }

    modifier onlyOwner(address addr) {
        require(addr == owner, unicode"无管理员权限");
        _;
    }

    function withdraw(address addr, uint256 amount) onlyOwner(msg.sender) public {
        // bank.withdraw(amount);
        IBank(addr).withdraw(amount);
        // (bool success, ) = addr.call(abi.encodeWithSignature("withdraw(uint256)", amount));
        // require(success,"failed");
    }

    function adminWithdraw(IBank bank, uint256 amount) onlyOwner(msg.sender) public {
        bank.withdraw(amount);
        // IBank(addr).withdraw(amount);
        // (bool success, ) = addr.call(abi.encodeWithSignature("withdraw(uint256)", amount));
        // require(success,"failed");
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}