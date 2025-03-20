// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingMining/StakingPool.sol";
import "../src/StakingMining/StakingMining.sol";
import "../src/StakingMining/RNT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingPoolTest is Test {
  using SafeERC20 for ERC20;
  using SafeERC20 for RNT;

  StakingPool staking;
  EsRNT esRNT;
  RNT rnt;
  address owner;
  address user1 = address(0x123);
  address user2 = address(0x456);
  address user3 = address(0x789);

  uint256 constant INITIAL_SUPPLY = 1e10 ether;
  uint256 constant REWARD_RATE = 10 ether;

  function setUp() public {
    owner = address(this);
    rnt = new RNT("RNT", "rnt");
    esRNT = new EsRNT("Escrowed Rent Token", "esRNT", address(rnt));
    staking = new StakingPool(address(esRNT));

    // 给 user 分配用于质押的 ETH
    vm.deal(user1, 100 ether);
    vm.deal(user2, 200 ether);
    vm.deal(user3, 200 ether);
  }

  // 测试质押结算
  function testStake() public {
    uint256[] memory r = new uint256[](7);
    uint256 blockNumber = block.number;
    // user1 质押 100 ETH
    vm.prank(user1);
    staking.stake{ value: 100 ether }();
    r[0] = 0;
    assertEq(staking.rewardPerTokenStored(), r[0]);

    // user2 质押 200 ETH
    vm.roll(blockNumber + 2);
    vm.prank(user2);
    staking.stake{ value: 200 ether }();
    r[1] = r[0] + 2 * REWARD_RATE * 1e18 / 100 ether;
    assertEq(staking.rewardPerTokenStored(), r[1]);

    // user3 质押 100 ETH
    vm.roll(blockNumber + 3);
    vm.prank(user3);
    staking.stake{ value: 100 ether }();
    r[2] = r[1] + 1 * REWARD_RATE * 1e18 / 300 ether;
    assertEq(staking.rewardPerTokenStored(), r[2]);

    // user1解除质押，验证user1的奖励
    vm.roll(blockNumber + 6);
    vm.startPrank(user1);
    staking.unstake(100 ether);
    r[3] = r[2] + 3 * REWARD_RATE * 1e18 / 400 ether;
    assertEq(staking.rewardPerTokenStored(), r[3]);
    assertEq(staking.earned(user1), 100 ether * (r[3] - r[0]) / 1e18);
    vm.stopPrank();

    // user3质押 100 ETH，验证user3的奖励
    vm.roll(blockNumber + 7);
    vm.prank(user3);
    staking.stake{ value: 100 ether }();
    r[4] = r[3] + 1 * REWARD_RATE * 1e18 / 300 ether;
    assertEq(staking.rewardPerTokenStored(), r[4]);
    assertEq(staking.earned(user3), 100 ether * (r[4] - r[2]) / 1e18);

    // user2解除质押，验证user2的奖励
    vm.roll(blockNumber + 8);
    vm.startPrank(user2);
    staking.unstake(200 ether);
    r[5] = r[4] + 1 * REWARD_RATE * 1e18 / 400 ether;
    assertEq(staking.rewardPerTokenStored(), r[5]);
    assertEq(staking.earned(user2), 200 ether * (r[5] - r[1]) / 1e18);
    vm.stopPrank();

    // user3解除质押，验证user3的奖励
    vm.roll(blockNumber + 10);
    vm.startPrank(user3);
    uint256 preReward = staking.getUserReward(user3);
    staking.unstake(200 ether);
    r[6] = r[5] + 2 * REWARD_RATE * 1e18 / 200 ether;
    assertEq(staking.rewardPerTokenStored(), r[6]);
    assertEq(staking.earned(user3), preReward + 200 ether * (r[6] - r[4]) / 1e18);
    vm.stopPrank();
  }

  receive() external payable { }
}
