// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract TokenBank {
  address public tokens;
  mapping(address => uint256) public balances;

  event Deposited(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);

  constructor(address _token) {
    tokens = _token;
  }

  modifier enoughBalance(address _addr, uint256 _amount) {
    require(balances[_addr] >= _amount, "TokenBank: Insufficient balance in TokenBank");
    _;
  }

  function deposit(uint256 amount) public {
    (bool success,) = tokens.call(abi.encodeCall(IERC20(tokens).transferFrom, (msg.sender, address(this), amount)));
    require(success, "TokenBank: deposit failed");
    balances[msg.sender] += amount;
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
    IERC20(tokens).transferFrom(owner, address(this), amount);
    balances[owner] += amount;
    emit Deposited(owner, amount);
  }

  function getDepositBalance(address user) public view returns (uint256) {
    return balances[user];
  }
}
