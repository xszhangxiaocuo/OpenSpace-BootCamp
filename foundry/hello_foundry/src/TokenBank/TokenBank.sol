// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BalanceList.sol";

contract TokenBank {
  address public tokens;
  mapping(address => uint256) public balances; // 所有用户的存款
  BalanceList public balanceList; // 前10名用户的存款

  event Deposited(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);

  constructor(address _token) {
    tokens = _token;
    balanceList = new BalanceList();
  }

  modifier enoughBalance(address _addr, uint256 _amount) {
    require(balances[_addr] >= _amount, "TokenBank: Insufficient balance in TokenBank");
    _;
  }

  function deposit(uint256 amount) public {
    (bool success,) = tokens.call(abi.encodeCall(IERC20(tokens).transferFrom, (msg.sender, address(this), amount)));
    require(success, "TokenBank: deposit failed");
    balances[msg.sender] += amount;
    rankDeposit(msg.sender);
    emit Deposited(msg.sender, amount);
  }

  function withdraw(uint256 amount) public enoughBalance(msg.sender, amount) {
    (bool success,) = tokens.call(abi.encodeCall(IERC20(tokens).transfer, (msg.sender, amount)));
    require(success, "TokenBank: withdraw failed");
    balances[msg.sender] -= amount;

    emit Withdrawn(msg.sender, amount);
  }

  function permitDeposit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
    require(amount > 0, "Amount must be greater than 0");
    IERC20Permit(tokens).permit(owner, spender, amount, deadline, v, r, s);
    // IERC20(tokens).transferFrom(owner, address(this), amount);
    SafeERC20.safeTransferFrom(IERC20(tokens), owner,address(this), amount); // 要使用SafeERC20进行安全转账
    balances[owner] += amount;
    rankDeposit(owner);
    emit Deposited(owner, amount);
  }

  // 如果存款排名发生变化，修改balanceList中的存款排名
  function rankDeposit(address user) public {
    uint256 userBalance = balances[user];
    uint256 minBalance = balanceList.getMinBalance();
    // 如果用户已经在前10名中，或存款大于最小存款，则更新存款排名
    if(balanceList.isUser(user)){ // 已经存在的用户更新存款
      balanceList.updateBalance(user, userBalance);
    }else if (userBalance > minBalance) { // 新用户存款大于前十名的最小存款
      balanceList.addUser(user, userBalance);
    }
  }

  function getDepositBalance(address user) public view returns (uint256) {
    return balances[user];
  }
}
