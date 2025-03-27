// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 极简的杠杆 DEX 实现， 完成 TODO 代码部分
contract SimpleLeverageDEX {
  uint256 public vK; // 初始虚拟池乘积，如 100000
  uint256 public vETHAmount;
  uint256 public vUSDCAmount;

  IERC20 public USDC; // 自己创建一个币来模拟 USDC

  struct PositionInfo {
    uint256 margin; // 保证金
    uint256 borrowed; // 借入的资金
    int256 position; // 虚拟 eth 持仓（正数为多头，负数为空头）
  }

  mapping(address => PositionInfo) public positions;

  constructor(uint256 vEth, uint256 vUSDC, address _usdc) {
    vETHAmount = vEth;
    vUSDCAmount = vUSDC;
    vK = vEth * vUSDC;
    USDC = IERC20(_usdc);
  }

  // 开启杠杆头寸
  function openPosition(uint256 _margin, uint256 level, bool long) external {
    require(positions[msg.sender].position == 0, "Position already open");

    PositionInfo storage pos = positions[msg.sender];

    USDC.transferFrom(msg.sender, address(this), _margin); // 用户提供保证金
    uint256 amount = _margin * level;
    uint256 borrowAmount = amount - _margin;

    pos.margin = _margin;
    pos.borrowed = borrowAmount;

    if (long) {
      // 用户买入 ETH，vUSDC 增加，vETH 减少
      uint256 ethBought = getAmountOut(amount, vUSDCAmount, vETHAmount);
      vUSDCAmount += amount;
      vETHAmount -= ethBought;
      pos.position = int256(ethBought);
    } else {
      // 用户卖出 ETH，vETH 增加，vUSDC 减少
      uint256 usdcReceived = getAmountOut(amount, vETHAmount, vUSDCAmount);
      vETHAmount += amount;
      vUSDCAmount -= usdcReceived;
      pos.position = -int256(amount);
    }

    // 更新虚拟池积（可选，保持 invariant 不变）
    vK = vETHAmount * vUSDCAmount;
  }

  // 关闭头寸并结算, 不考虑协议亏损
  function closePosition() external {
    PositionInfo storage pos = positions[msg.sender];
    require(pos.position != 0, "No open position");

    int256 pnl = calculatePnL(msg.sender);
    uint256 finalAmount;

    if (pnl >= 0) {
        finalAmount = pos.margin + uint256(pnl);
    } else {
        uint256 loss = uint256(-pnl);
        require(pos.margin > loss, "Loss exceeds margin");
        finalAmount = pos.margin - loss;
    }

    // 防止合约余额不足导致 revert（例如测试时 USDC 不够）
    uint256 contractBalance = USDC.balanceOf(address(this));
    if (finalAmount > contractBalance) {
        finalAmount = contractBalance;
    }

    USDC.transfer(msg.sender, finalAmount);
    delete positions[msg.sender];
}

  // 清算头寸
  function liquidatePosition(address _user) external {
    require(msg.sender != _user, "Can't liquidate yourself");
    PositionInfo memory position = positions[_user];
    require(position.position != 0, "No open position");

    int256 pnl = calculatePnL(_user);
    uint256 margin = position.margin;

    if (pnl < 0) {
      uint256 loss = uint256(-pnl);
      require(loss >= margin * 80 / 100, "Not eligible for liquidation");
    } else {
      revert("Position is not under liquidation threshold");
    }

    // 将剩余保证金给清算人（激励）
    uint256 remaining = margin > uint256(-pnl) ? margin - uint256(-pnl) : 0;
    if (remaining > 0) {
      USDC.transfer(msg.sender, remaining);
    }

    delete positions[_user];
  }

  // 根据当前 vAMM 计算盈亏
  function calculatePnL(address user) public view returns (int256) {
    PositionInfo memory pos = positions[user];
    int256 ethPos = pos.position;
    if (ethPos == 0) return 0;

    uint256 curPrice = vUSDCAmount * 1e18 / vETHAmount;

    if (ethPos > 0) {
        // 多头
        uint256 ethAmount = uint256(ethPos);
        uint256 positionValue = ethAmount * curPrice / 1e18;
        if (positionValue > pos.borrowed) {
            return int256(positionValue - pos.borrowed);
        } else {
            return -int256(pos.borrowed - positionValue);
        }
    } else {
        // 空头
        uint256 ethAmount = uint256(-ethPos);
        uint256 costToRepurchase = ethAmount * curPrice / 1e18;
        if (costToRepurchase < pos.borrowed) {
            return int256(pos.borrowed - costToRepurchase);
        } else {
            return -int256(costToRepurchase - pos.borrowed);
        }
    }
}

  // vAMM 的定价函数：x * y = k 模拟
  function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
    // 忽略手续费的简化版本
    uint256 amountInWithFee = amountIn;
    uint256 numerator = amountInWithFee * reserveOut;
    uint256 denominator = reserveIn + amountInWithFee;
    return numerator / denominator;
  }

  // 仅用于测试模拟价格变化
  function adjustVirtualReserves(uint256 newVETH, uint256 newVUSDC) external {
    vETHAmount = newVETH;
    vUSDCAmount = newVUSDC;
    vK = vETHAmount * vUSDCAmount;
  }
}
