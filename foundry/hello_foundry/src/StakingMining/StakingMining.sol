// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {EsRNT} from "./esRNT.sol";

// 质押挖矿合约
contract StakingMining is ReentrancyGuardTransient, Ownable {
  using SafeERC20 for IERC20;
  using SafeERC20 for EsRNT;

  IERC20 public rnt; // RNT 代币
  EsRNT public esRNT; // esRNT 代币（锁仓代币）

  uint256 public constant REWARD_RATE = 1e18; // 每质押 1 RNT 每天奖励 1 esRNT (18 位小数)
  uint256 public constant SECONDS_PER_DAY = 86400;
  address constant public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD; // 代币销毁地址

  // 用户质押信息
  struct StakeInfo {
    uint256 amount; // 质押的 RNT 数量
    uint256 lastUpdate; // 上次更新时间
    uint256 pendingRewards; // 未领取的 esRNT 奖励
  }

  mapping(address => StakeInfo) public stakes;

  event Staked(address indexed user, uint256 amount);
  event Unstaked(address indexed user, uint256 amount);
  event RewardsClaimed(address indexed user, uint256 amount);

  constructor(address _rnt, address _esRNT) Ownable(msg.sender) {
    rnt = IERC20(_rnt);
    esRNT = EsRNT(_esRNT);
  }

  // 更新用户的奖励
  function updateRewards(address user) internal {
    StakeInfo storage stake = stakes[user];
    if (stake.amount == 0) return;
    uint256 currentTime = block.timestamp;
    uint256 timeElapsed = currentTime - stake.lastUpdate;
    uint256 newRewards = (stake.amount * REWARD_RATE * timeElapsed) / (1e18 * SECONDS_PER_DAY);
    stake.pendingRewards += newRewards;
    stake.lastUpdate = currentTime;
  }

  // 用户质押 RNT
  function staked(uint256 amount) external nonReentrant {
    require(amount > 0, "Amount must be greater than 0");

    updateRewards(msg.sender);

    stakes[msg.sender].amount += amount;
    stakes[msg.sender].lastUpdate = block.timestamp;
    rnt.safeTransferFrom(msg.sender, address(this), amount);

    emit Staked(msg.sender, amount);
  }

  // 用户解押 RNT
  function unstake(uint256 amount) external nonReentrant {
    require(amount > 0, "Amount must be greater than 0");
    StakeInfo storage stake = stakes[msg.sender];
    require(stake.amount >= amount, "Insufficient staked amount");

    updateRewards(msg.sender);

    stake.amount -= amount;
    rnt.safeTransfer(msg.sender, amount);

    emit Unstaked(msg.sender, amount);
  }

  // 用户领取 esRNT 奖励
  function claimRewards() external nonReentrant {
    updateRewards(msg.sender);
    StakeInfo storage stake = stakes[msg.sender];
    uint256 reward = stake.pendingRewards;
    require(reward > 0, "No rewards to claim");

    stake.pendingRewards = 0;
    rnt.approve(address(esRNT), reward);
    esRNT.mint(msg.sender, reward);

    emit RewardsClaimed(msg.sender, reward);
  }

  // 兑换 esRNT 为 RNT（支持提前兑换，锁定部分燃烧）
  function convertEsRNT(uint256 id) external nonReentrant {
    uint256 burn = esRNT.convertEsRNT(msg.sender, id);
    if (burn > 0) {
      esRNT.safeTransferFrom(msg.sender, BURN_ADDRESS, burn);
    }
  }

  // 查看用户的质押信息
  function getStakeInfo(address user) external view returns (uint256 amount, uint256 pendingRewards) {
    StakeInfo memory stake = stakes[user];
    uint256 timeElapsed = block.timestamp - stake.lastUpdate;
    uint256 newRewards = (stake.amount * REWARD_RATE * timeElapsed) / (1e18 * SECONDS_PER_DAY);
    return (stake.amount, stake.pendingRewards+newRewards);
  }
}
