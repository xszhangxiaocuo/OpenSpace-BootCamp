// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CallOptionToken/CallOptionToken.sol";

contract CallOptionTokenTest is Test {
  CallOptionToken public option;
  MockUSDT public usdt;

  address user = address(0x123);
  address treasury = address(this);

  uint256 strikePrice = 1800 * 1e6; // 1800 USDT, 6 decimals
  uint256 expiry;

  function setUp() public {
    expiry = block.timestamp + 1 days;

    // Deploy mock USDT
    usdt = new MockUSDT();

    // Deploy the option contract
    option = new CallOptionToken(address(usdt), strikePrice, expiry);
  }

  /// -----------------------------
  /// ✅ 正常流程测试
  /// -----------------------------

  function testMintOption() public {
    vm.deal(user, 1 ether);

    vm.prank(user);
    option.mintOption{ value: 1 ether }();

    assertEq(option.balanceOf(user), 1 ether);
    assertEq(address(option).balance, 1 ether);
  }

  function testExercise() public {
    vm.deal(user, 1 ether);
    vm.prank(user);
    option.mintOption{ value: 1 ether }();

    // 准备 USDT
    vm.warp(expiry);
    usdt.mint(user, strikePrice);
    vm.startPrank(user);
    usdt.approve(address(option), strikePrice);

    option.exercise(1 ether);
    vm.stopPrank();

    // 检查 ETH 和 OptionToken
    assertEq(user.balance, 1 ether);
    assertEq(option.balanceOf(user), 0);
    assertEq(usdt.balanceOf(treasury), strikePrice);
  }

  function testExpireAfterDeadline() public {
    vm.deal(user, 1 ether);
    vm.prank(user);
    option.mintOption{ value: 1 ether }();

    vm.warp(expiry + 1 days + 1); // 超过行权期

    uint256 before = treasury.balance;
    option.expire();
    uint256 afterBalance = treasury.balance;

    assertGt(afterBalance, before);
    assertTrue(option.expired());
  }

  /// -----------------------------
  /// ❌ 异常流程测试（使用 expectRevert）
  /// -----------------------------

  function test_RevertWhen_MintAfterExpiry() public {
    vm.warp(expiry + 1);
    vm.expectRevert("Option expired");
    option.mintOption{ value: 1 ether }();
  }

  function test_RevertWhen_ExerciseBeforeExpiry() public {
    vm.deal(user, 1 ether);
    vm.prank(user);
    option.mintOption{ value: 1 ether }();

    vm.prank(user);
    vm.expectRevert("Not exercisable now");
    option.exercise(1 ether);
  }

  function test_RevertWhen_ExpireTooEarly() public {
    vm.expectRevert("Too early to expire");
    option.expire();
  }

  receive() external payable { }
}

/// @dev 简单的 mock USDT，用于测试行权支付
contract MockUSDT is ERC20 {
  constructor() ERC20("Mock USDT", "USDT") { }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}
