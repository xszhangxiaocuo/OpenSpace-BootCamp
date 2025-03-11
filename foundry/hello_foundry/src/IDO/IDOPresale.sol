// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * 编写 IDO 合约，实现 Token 预售，需要实现如下功能：
 *
 * 开启预售: 支持对给定的任意ERC20开启预售，设定预售价格，募集ETH目标，超募上限，预售时长。
 * 任意用户可支付ETH参与预售；
 * 预售结束后，如果没有达到募集目标，则用户可领会退款；
 * 预售成功，用户可领取 Token，且项目方可提现募集的ETH；
 */
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol"; // 防止重入攻击，使用瞬时存储
import "@openzeppelin/contracts/access/Ownable.sol";

contract IDOPresale is ReentrancyGuardTransient, Ownable {
  using SafeERC20 for IERC20;
  // 预售状态枚举

  enum SaleState {
    NotStarted,
    Active,
    Failed,
    Success
  }

  // 预售参数结构体
  struct PresaleInfo {
    IERC20 token; // 预售的 ERC20 代币
    uint256 price; // 每个代币的价格 (wei)
    uint256 goal; // 募集目标 (wei)
    uint256 cap; // 超募上限 (wei)
    uint256 duration; // 预售时长 (秒)
    uint256 startTime; // 开始时间
    uint256 totalRaised; // 已募集的 ETH 总量（wei）
    SaleState state; // 预售状态
  }

  PresaleInfo public presale;
  mapping(address => uint256) public contributions; // 用户的 ETH 贡献
  bool public isWithdrawn; // 项目方是否已提取 ETH

  event PresaleStarted(address token, uint256 price, uint256 goal, uint256 cap, uint256 duration);
  event Contributed(address contributor, uint256 amount);
  event TokensClaimed(address user, uint256 amount);
  event Refunded(address user, uint256 amount);
  event FundsWithdrawn(uint256 amount);

  constructor() Ownable(msg.sender) { }

  // 开启预售
  function startPresale(address _token, uint256 _price, uint256 _goal, uint256 _cap, uint256 _duration) external onlyOwner {
    require(address(presale.token) == address(0), "Presale already started");
    require(_token != address(0), "Invalid token address");
    require(_price > 0, "Price must be greater than 0");
    require(_goal > 0, "Goal must be greater than 0");
    require(_cap >= _goal, "Cap must be >= goal");
    require(_duration > 0, "Duration must be greater than 0");

    presale =
      PresaleInfo({ token: IERC20(_token), price: _price, goal: _goal, cap: _cap, duration: _duration, startTime: block.timestamp, totalRaised: 0, state: SaleState.Active });

    emit PresaleStarted(_token, _price, _goal, _cap, _duration);
  }

  // 用户参与预售
  function contribute() external payable nonReentrant {
    require(presale.state == SaleState.Active, "Presale not active");
    require(block.timestamp < presale.startTime + presale.duration, "Presale ended");
    require(msg.value > 0, "Contribution must be > 0");
    require(presale.totalRaised + msg.value <= presale.cap, "Exceeds cap");

    presale.totalRaised += msg.value;
    contributions[msg.sender] += msg.value;

    emit Contributed(msg.sender, msg.value);
  }

  // 更新预售状态
  function updateState() public {
    if (presale.state != SaleState.Active) return;

    if (block.timestamp >= presale.startTime + presale.duration) {
      if (presale.totalRaised >= presale.goal) {
        presale.state = SaleState.Success;
      } else {
        presale.state = SaleState.Failed;
      }
    }
  }

  // 用户领取 Token（预售成功时）
  function claimTokens() external nonReentrant {
    updateState();
    require(presale.state == SaleState.Success, "Cannot claim tokens");
    require(contributions[msg.sender] > 0, "No contribution");

    uint256 ethContributed = contributions[msg.sender];
    uint256 tokenAmount = (ethContributed * 1e18) / presale.price; // 计算用户应获得的 Token 数量

    contributions[msg.sender] = 0;
    presale.token.safeTransfer(msg.sender, tokenAmount);

    emit TokensClaimed(msg.sender, tokenAmount);
  }

  // 用户领取退款（预售失败时）
  function claimRefund() external nonReentrant {
    updateState();
    require(presale.state == SaleState.Failed, "Cannot claim refund");
    require(contributions[msg.sender] > 0, "No contribution");

    // 先修改用户的贡献记录，再退款，防止重入攻击
    uint256 amount = contributions[msg.sender];
    contributions[msg.sender] = 0;

    (bool success,) = msg.sender.call{ value: amount }("");
    require(success, "Refund failed");

    emit Refunded(msg.sender, amount);
  }

  // 项目方提取募集的 ETH（预售成功时）
  function withdrawFunds() external onlyOwner nonReentrant {
    updateState();
    require(presale.state == SaleState.Success, "Cannot withdraw yet");
    require(!isWithdrawn, "Already withdrawn");

    isWithdrawn = true;
    uint256 amount = presale.totalRaised;

    (bool success,) = msg.sender.call{ value: amount }("");
    require(success, "Withdrawal failed");

    emit FundsWithdrawn(amount);
  }

  // 查看预售状态
  function getPresaleInfo()
    external
    view
    returns (address token, uint256 price, uint256 goal, uint256 cap, uint256 duration, uint256 startTime, uint256 totalRaised, SaleState state)
  {
    return (address(presale.token), presale.price, presale.goal, presale.cap, presale.duration, presale.startTime, presale.totalRaised, presale.state);
  }
}
