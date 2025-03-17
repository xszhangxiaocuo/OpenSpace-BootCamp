// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。

TokenBank 有两个方法：
deposit() : 需要记录每个地址的存入数量；
withdraw（）: 用户可以提取自己的之前存入的 token。

(自动化)当存款超过 x 时，转移一半的存款的到指定的地址。
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

// 0x241C1a25ee7683Ab537d04748dE53B499025B416
contract AutoBank is Ownable, AutomationCompatibleInterface {
  using SafeERC20 for IERC20;
  address public tokens;
  address public to; // 转移地址
  uint256 public x; // 存款超过 x 时，转移一半的存款的到指定的地址

  mapping(address => uint256) public balances;

  event Deposited(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);

  constructor(address _token,address _to,uint256 _x) Ownable(msg.sender) {
    tokens = _token;
    to = _to;
    x = _x;
  }

  modifier enoughBalance(address _addr, uint256 _amount) {
    require(balances[_addr] >= _amount, "TokenBank: Insufficient balance in TokenBank");
    _;
  }

  function deposit(uint256 amount) public {
    IERC20(tokens).safeTransferFrom(msg.sender, address(this), amount);
    balances[msg.sender] += amount;
    emit Deposited(msg.sender, amount);
  }

  function withdraw(uint256 amount) public enoughBalance(msg.sender, amount) {
    balances[msg.sender] -= amount;
    IERC20(tokens).safeTransfer(msg.sender, amount);

    emit Withdrawn(msg.sender, amount);
  }

  function getDepositBalance(address user) public view returns (uint256) {
    return balances[user];
  }

  function setTo(address _to) public onlyOwner {
    to = _to;
  }

  function setX(uint256 _x) public onlyOwner {
    x = _x;
  }

  function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
    uint256 total = IERC20(tokens).balanceOf(address(this));
    if (total > x) {
      uint256 amount = total / 2;
      return (true, abi.encode(amount));
    }
    return (false, "");
  }

  function performUpkeep(bytes calldata performData) external override {
    uint256 amount = abi.decode(performData, (uint256));
    IERC20(tokens).safeTransfer(to, amount);
  }
}
