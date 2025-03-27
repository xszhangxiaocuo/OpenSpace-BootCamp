// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LeverageDEX/SimpleLeverageDEX.sol";

// 一个简单的 USDC mock token
contract MockUSDC is IERC20 {
  string public name = "Mock USDC";
  string public symbol = "USDC";
  uint8 public decimals = 6;
  uint256 public totalSupply;

  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  function transfer(address to, uint256 amount) external returns (bool) {
    balanceOf[msg.sender] -= amount;
    balanceOf[to] += amount;
    return true;
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    allowance[msg.sender][spender] = amount;
    return true;
  }

  function transferFrom(address from, address to, uint256 amount) external returns (bool) {
    require(allowance[from][msg.sender] >= amount, "Not approved");
    allowance[from][msg.sender] -= amount;
    balanceOf[from] -= amount;
    balanceOf[to] += amount;
    return true;
  }

  function mint(address to, uint256 amount) external {
    balanceOf[to] += amount;
    totalSupply += amount;
  }
}

contract SimpleLeverageDEXTest is Test {
  SimpleLeverageDEX dex;
  MockUSDC usdc;
  address alice = address(0xA1);
  address bob = address(0xB1);

  function setUp() public {
    usdc = new MockUSDC();
    dex = new SimpleLeverageDEX(1000e18, 1000e6, address(usdc)); // vETH: 1000, vUSDC: 1000

    usdc.mint(alice, 10000e6);
    usdc.mint(bob, 10000e6);

    vm.startPrank(alice);
    usdc.approve(address(dex), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(bob);
    usdc.approve(address(dex), type(uint256).max);
    vm.stopPrank();
  }

  function testOpenAndCloseLong() public {
    vm.startPrank(alice);

    dex.openPosition(100e6, 5, true); // 保证金100，5倍杠杆 = 500 USDC 买多

    (,, int256 position) = dex.positions(alice);
    assertGt(position, 0); // 多头头寸应该为正

    dex.closePosition();

    (,, int256 newPos) = dex.positions(alice);
    assertEq(newPos, 0); // 仓位已清
    vm.stopPrank();
  }

  function testOpenAndCloseShort() public {
    vm.startPrank(alice);

    dex.openPosition(100e6, 5, false); // 保证金100，空头头寸

    (,, int256 position) = dex.positions(alice);
    assertLt(position, 0); // 空头仓位为负

    dex.closePosition();

    (,, int256 newPos) = dex.positions(alice);
    assertEq(newPos, 0); // 仓位已清

    vm.stopPrank();
  }

function testLiquidation() public {
    vm.startPrank(alice);
    dex.openPosition(100e6, 5, true); // 多头
    vm.stopPrank();

    // 模拟价格暴跌：vETH 增加，价格变低
    uint newVETH = dex.vETHAmount() * 10;
    dex.adjustVirtualReserves(newVETH, dex.vUSDCAmount());

    vm.startPrank(bob);
    dex.liquidatePosition(alice); // bob 清算 alice
    vm.stopPrank();

    (, , int256 pos) = dex.positions(alice);
    assertEq(pos, 0); // 被清算后仓位为 0
}

  function testCannotLiquidateHealthyPosition() public {
    vm.startPrank(alice);
    dex.openPosition(100e6, 2, true);
    vm.stopPrank();

    vm.expectRevert();
    vm.prank(bob);
    dex.liquidatePosition(alice);
  }
}
