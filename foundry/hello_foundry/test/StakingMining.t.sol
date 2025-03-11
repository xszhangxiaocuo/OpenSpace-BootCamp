// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingMining/StakingMining.sol";
import "../src/StakingMining/RNT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingMiningTest is Test {
  using SafeERC20 for ERC20;
  using SafeERC20 for RNT;

  StakingMining staking;
  RNT rnt;
  EsRNT esRNT;
  address owner;
  address user1 = address(0x123);

  uint256 constant INITIAL_SUPPLY = 1e10 ether;

  function setUp() public {
    owner = address(this);
    rnt = new RNT("Rent Token", "RNT");
    esRNT = new EsRNT("Escrowed Rent Token", "esRNT", address(rnt));
    staking = new StakingMining(address(rnt), address(esRNT));

    // 给 StakingMining 合约转入RNT
    rnt.safeTransfer(address(staking), INITIAL_SUPPLY / 2);

    // 给 user1 分配用于质押的 RNT
    rnt.safeTransfer(user1, 100 ether);
  }

  // 测试质押 RNT
  function testStake() public {
    uint256 stakeAmount = 10 ether;
    vm.startPrank(user1);
    rnt.approve(address(staking), stakeAmount);
    staking.staked(stakeAmount);
    vm.stopPrank();

    (uint256 amount, uint256 rewards) = staking.getStakeInfo(user1);
    assertEq(amount, stakeAmount);
    assertEq(rnt.balanceOf(user1), 90 ether);
    assertEq(rnt.balanceOf(address(staking)), INITIAL_SUPPLY / 2 + 10 ether);
  }

  // 测试解押 RNT
  function testUnstake() public {
    uint256 stakeAmount = 10 ether;
    vm.startPrank(user1);
    rnt.approve(address(staking), stakeAmount);
    staking.staked(stakeAmount);
    vm.stopPrank();

    vm.warp(block.timestamp + 1 days); // 快进 1 天
    vm.prank(user1);
    staking.unstake(stakeAmount);

    (uint256 amount, uint256 rewards) = staking.getStakeInfo(user1);
    assertEq(amount, 0);
    assertEq(rnt.balanceOf(user1), 100 ether); // 恢复初始余额
  }

  // 测试领取 esRNT 奖励
  function testClaimRewards() public {
    uint256 stakeAmount = 10 ether;
    uint256 currentTime = block.timestamp;
    vm.startPrank(user1);
    rnt.approve(address(staking), stakeAmount);
    staking.staked(stakeAmount);
    vm.stopPrank();

    vm.warp(currentTime + 2 days); // 快进 2 天
    vm.prank(user1);
    staking.claimRewards();

    (uint256 amount, uint256 rewards) = staking.getStakeInfo(user1);
    assertEq(amount, stakeAmount);
    assertEq(esRNT.balanceOf(user1), 20 ether);
  }

  // 测试完全解锁后兑换 esRNT
  function testConvertEsRNTFullUnlock() public {
    uint256 stakeAmount = 10 ether;
    vm.startPrank(user1);
    rnt.approve(address(staking), stakeAmount);
    staking.staked(stakeAmount);
    vm.stopPrank();

    vm.warp(block.timestamp + 1 days);
    vm.prank(user1);
    staking.claimRewards(); // 领取 10 esRNT

    vm.warp(block.timestamp + 30 days); // 快进 30 天，完全解锁
    vm.startPrank(user1);
    esRNT.approve(address(staking), esRNT.balanceOf(user1));
    vm.expectEmit(true, false, false, true);
    emit EsRNT.EsRNTConverted(user1, 10 ether, 10 ether, 0);
    staking.convertEsRNT(0);
    vm.stopPrank();

    assertEq(rnt.balanceOf(user1), 100 ether);
    assertEq(esRNT.balanceOf(user1), 0);
  }

  // 测试提前兑换 esRNT（部分燃烧）
  function testConvertEsRNTPartialUnlock() public {
    uint256 stakeAmount = 10 ether;
    vm.startPrank(user1);
    rnt.approve(address(staking), stakeAmount);
    staking.staked(stakeAmount);
    vm.stopPrank();

    vm.warp(block.timestamp + 1 days);
    vm.prank(user1);
    staking.claimRewards(); // 领取 10 esRNT

    vm.warp(block.timestamp + 15 days); // 快进 15 天，解锁一半
    vm.startPrank(user1);
    esRNT.approve(address(staking), esRNT.balanceOf(user1));
    vm.expectEmit(true, false, false, true);
    emit EsRNT.EsRNTConverted(user1, 10 ether, 5 ether, 5 ether);
    staking.convertEsRNT(0);
    vm.stopPrank();

    assertEq(rnt.balanceOf(user1), 95 ether);
    assertEq(esRNT.balanceOf(user1), 0);
  }

  // 测试无质押时领取奖励应回滚
  function test_RevertWhen_ClaimRewardsNoStake() public {
    vm.prank(user1);
    vm.expectRevert("No rewards to claim");
    staking.claimRewards();
  }

  // 测试解押超过质押量应回滚
  function test_RevertWhen_UnstakeExceedsAmount() public {
    vm.prank(user1);
    vm.expectRevert("Insufficient staked amount");
    staking.unstake(10 ether);
  }

  receive() external payable { }
}
