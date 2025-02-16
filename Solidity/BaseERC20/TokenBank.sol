// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。

TokenBank 有两个方法：
deposit() : 需要记录每个地址的存入数量；
withdraw（）: 用户可以提取自己的之前存入的 token。
*/

import "./BaseERC20.sol";

contract TokenBank {
    address public tokens;
    mapping(address => uint) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _token) {
         tokens = _token;
     }

    function deposit(uint256 amount) public  {
        require(amount > 0, "Amount should be greater than 0");
        (bool success,) = tokens.call(abi.encodeCall(BaseERC20(tokens).transferFrom,(msg.sender,address(this),amount)));
        require(success,"deposit failed");
        balances[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance in TokenBank");
        (bool success,) = tokens.call(abi.encodeCall(BaseERC20(tokens).transfer,(msg.sender,amount)));
        require(success,"withdraw failed");
        balances[msg.sender] -= amount;

        emit Withdrawn(msg.sender, amount);
    }

    function getDepositBalance(address user) public view returns (uint256) {
        return balances[user];
    }
}