// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * 编写 StakingPool 合约，实现 Stake 和 Unstake 方法，允许任何人质押ETH来赚取 KK Token。
 * 其中 KK Token 是每一个区块产出 10 个，产出的 KK Token 需要根据质押时长和质押数量来公平分配。
 */

/**
 * @title KK Token
 */
interface IToken is IERC20 {
  function mint(address to, uint256 amount) external;
}

/**
 * @title Staking Interface
 */
interface IStaking {
  /**
   * @dev 质押 ETH 到合约
   */
  function stake() external payable;

  /**
   * @dev 赎回质押的 ETH
   * @param amount 赎回数量
   */
  function unstake(uint256 amount) external;

  /**
   * @dev 领取 KK Token 收益
   */
  function claim() external;

  /**
   * @dev 获取质押的 ETH 数量
   * @param account 质押账户
   * @return 质押的 ETH 数量
   */
  function balanceOf(address account) external view returns (uint256);

  /**
   * @dev 获取待领取的 KK Token 收益
   * @param account 质押账户
   * @return 待领取的 KK Token 收益
   */
  function earned(address account) external view returns (uint256);
}

contract StakingPool is IStaking {
  // KK Token 合约实例
  IToken public token;

  // 总质押的 ETH 数量
  uint256 public totalStaked;

  struct User {
    uint256 amount; // 质押数量
    uint256 reward; // 待领取奖励
    uint256 lastUpdateBlock; // 上次更新奖励的区块号
    uint256 lastRewardPerToken; // 上次更新奖励时的 rewardPerTokenStored
  }

  // 每单位质押 ETH 的累积奖励（精度 1e18）
  uint256 public rewardPerTokenStored;
  uint256 public lastUpdateBlock; // 上次更新奖励的区块号
  uint256 public constant rewardRate = 10 ether; // 每个区块产出的奖励

  mapping(address => User) public users;

  // 构造函数，初始化 KK Token 地址
  constructor(address _token) {
    token = IToken(_token);
  }

  // 质押 ETH
  function stake() external payable override {
    _updateRewardPerTokenStored(); // 更新全局奖励
    _updateUserReward(msg.sender); // 更新用户奖励
    users[msg.sender].amount += msg.value; // 增加用户质押数量
    totalStaked += msg.value; // 增加总质押数量
  }

  // 赎回 ETH
  function unstake(uint256 amount) external override {
    require(amount <= users[msg.sender].amount, "Insufficient balance");
    _updateRewardPerTokenStored(); // 更新全局奖励
    _updateUserReward(msg.sender); // 更新用户奖励
    users[msg.sender].amount -= amount; // 减少用户质押数量
    totalStaked -= amount; // 减少总质押数量
    payable(msg.sender).transfer(amount); // 转回 ETH
  }

  // 领取 KK Token 奖励
  function claim() external override {
    uint256 reward = users[msg.sender].reward;
    require(reward > 0, "No reward to claim");
    if (reward > 0) {
      users[msg.sender].reward = 0; // 清零已领取的奖励
      token.mint(msg.sender, reward); // mint 奖励给用户
    }
  }

  // 查询用户的质押数量
  function balanceOf(address account) external view override returns (uint256) {
    return users[account].amount;
  }

  // 查询用户的待领取奖励
  function earned(address account) external view override returns (uint256) {
    uint256 rewardPerToken = rewardPerTokenStored;
    User memory user = users[account];
    if (totalStaked > 0) {
      // 计算从上次更新到当前区块的额外奖励
      rewardPerToken += (block.number - lastUpdateBlock) * rewardRate * 1e18 / totalStaked;
    }
    // 返回已累积奖励 + 未累积的实时奖励
    return user.reward + (user.amount * (rewardPerToken - user.lastRewardPerToken) / 1e18);
  }

  function getUserReward(address account) external view returns (uint256) {
    return users[account].reward;
  }

  // 更新全局累计奖励（每质押一个eth可以赚取的token）
  function _updateRewardPerTokenStored() internal {
    if (totalStaked == 0) {
      lastUpdateBlock = block.number;
      return;
    }
    rewardPerTokenStored += (block.number - lastUpdateBlock) * rewardRate * 1e18 / totalStaked;
  }

  // 更新用户累计奖励
  function _updateUserReward(address account) internal {
    User storage user = users[account];
    if (user.amount == 0) {
      user.lastUpdateBlock = block.number;
      user.lastRewardPerToken = rewardPerTokenStored;
      return;
    }
    // 计算从上次更新到当前区块的额外奖励
    user.reward += user.amount * (rewardPerTokenStored - user.lastRewardPerToken) / 1e18;
    user.lastUpdateBlock = block.number;
    user.lastRewardPerToken = rewardPerTokenStored;
  }
}
