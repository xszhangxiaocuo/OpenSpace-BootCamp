// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/IDO/IDOPresale.sol";
import "../src/EIP2612/MyToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract IDOPresaleTest is Test {
    using SafeERC20 for MyToken;
    IDOPresale ido;
    MyToken token;
    address owner = address(0x123);
    address user1 = address(0x456);
    address user2 = address(0x789);

    uint256 price = 0.1 ether;      
    uint256 goal = 1 ether;       
    uint256 cap = 2 ether;         
    uint256 duration = 1 days;    
    uint256 tokenSupply = 100 ether;

    function setUp() public {
        vm.startPrank(owner);
        token = new MyToken("Hoshino","ho");
        ido = new IDOPresale();
        
        // 将 Token 转给 IDO 合约用于预售
        token.safeTransfer(address(ido), tokenSupply);
        vm.stopPrank();
    }

    // 测试开启预售
    function testStartPresale() public {
        vm.startPrank(owner);
        ido.startPresale(address(token), price, goal, cap, duration);
        (
            address tokenAddr,
            uint256 presalePrice,
            uint256 presaleGoal,
            uint256 presaleCap,
            uint256 presaleDuration,
            uint256 startTime,
            uint256 totalRaised,
            IDOPresale.SaleState state
        ) = ido.getPresaleInfo();
        vm.stopPrank();

        assertEq(tokenAddr, address(token));
        assertEq(presalePrice, price);
        assertEq(presaleGoal, goal);
        assertEq(presaleCap, cap);
        assertEq(presaleDuration, duration);
        assertEq(totalRaised, 0);
        assertEq(uint(state), uint(IDOPresale.SaleState.Active));
    }

    // 测试用户参与预售
    function testContribute() public {
        vm.prank(owner);
        ido.startPresale(address(token), price, goal, cap, duration);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        ido.contribute{value: 0.5 ether}();

        assertEq(ido.contributions(user1), 0.5 ether);
        (,,,,,,uint256 totalRaised,) = ido.getPresaleInfo();
        assertEq(totalRaised, 0.5 ether);
    }

    // 测试预售成功后领取 Token
    function testClaimTokensSuccess() public {
        vm.prank(owner);
        ido.startPresale(address(token), price, goal, cap, duration);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        ido.contribute{value: 1 ether}(); // 达到目标

        // 快进时间到预售结束
        vm.warp(block.timestamp + duration + 1);
        // ido.updateState();

        vm.prank(user1);
        ido.claimTokens();

        uint256 expectedTokens = (1 ether * 1e18) / price; // 10 Token (10^19 wei)
        assertEq(token.balanceOf(user1), expectedTokens);
        assertEq(ido.contributions(user1), 0);
    }

    // 测试预售失败后退款
    function testClaimRefundFailure() public {
        vm.prank(owner);
        ido.startPresale(address(token), price, goal, cap, duration);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        ido.contribute{value: 0.5 ether}(); // 未达到目标

        // 快进时间到预售结束
        vm.warp(block.timestamp + duration + 1);
        // ido.updateState();

        uint256 balanceBefore = user1.balance;
        vm.prank(user1);
        ido.claimRefund();

        assertEq(user1.balance, balanceBefore + 0.5 ether);
        assertEq(ido.contributions(user1), 0);
    }

    // 测试项目方提取资金
    function testWithdrawFunds() public {
        vm.prank(owner);
        ido.startPresale(address(token), price, goal, cap, duration);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        ido.contribute{value: 1 ether}(); // 达到目标

        // 快进时间到预售结束
        vm.warp(block.timestamp + duration + 1);
        // ido.updateState();

        uint256 balanceBefore = owner.balance;
        vm.prank(owner);
        ido.withdrawFunds();

        assertEq(owner.balance, balanceBefore + 1 ether);
        assertTrue(ido.isWithdrawn());
    }

    // 测试未达到目标时无法提取资金
    function testWithdrawFundsWhenFailed() public {
        vm.prank(owner);
        ido.startPresale(address(token), price, goal, cap, duration);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        ido.contribute{value: 0.5 ether}(); // 未达到目标

        vm.warp(block.timestamp + duration + 1);
        // ido.updateState();

        vm.prank(owner);
        vm.expectRevert("Cannot withdraw yet");
        ido.withdrawFunds();
    }

    // 测试超过上限的贡献
    function testContributeExceedsCap() public {
        vm.prank(owner);
        ido.startPresale(address(token), price, goal, cap, duration);
        vm.deal(user1, 3 ether);
        vm.prank(user1);
        vm.expectRevert("Exceeds cap");
        ido.contribute{value: 3 ether}(); // 超过 2 ETH 上限
    }
}