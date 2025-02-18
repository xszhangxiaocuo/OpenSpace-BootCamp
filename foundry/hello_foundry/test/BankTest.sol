// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/bank.sol";

contract BankTest is Test {
    Bank bank;
    address user = address(0x123); // 测试用户地址

    function setUp() public {
        bank = new Bank();
    }

    function testDepositETH() public {
        uint256 depositAmount = 1 ether;
        vm.deal(user, 10 ether);

        // 1. 检查存款前余额
        uint256 initialBalance = bank.balanceOf(user);
        assertEq(initialBalance, 0, "Initial balance should be 0");

        // 2. 监听 Deposit 事件
        vm.expectEmit(true, true, true, true);
        emit Bank.Deposit(user, depositAmount);

        // 3. 执行存款交易
        vm.prank(user); // 让 `user` 作为 `msg.sender` 进行调用
        bank.depositETH{value: depositAmount}();

        // 4. 检查存款后余额
        uint256 newBalance = bank.balanceOf(user);
        assertEq(newBalance, depositAmount, "Balance should be updated correctly");
    }
}