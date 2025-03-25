// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract FlashSwap is IUniswapV2Callee {
    address immutable owner;
    address immutable factoryA; // PoolA 的工厂地址
    address immutable factoryB; // PoolB 的工厂地址

    constructor(address _factoryA, address _factoryB) {
        owner = msg.sender;
        factoryA = _factoryA;
        factoryB = _factoryB;
    }

    // 发起闪电兑换，从 PoolA 借入 tokenA
    function startFlashSwap(
        address tokenA,
        address tokenB,
        uint amountA
    ) external {
        address pairA = IUniswapV2Factory(factoryA).getPair(tokenA, tokenB);
        require(pairA != address(0), "Pair A does not exist");

        // 确定 tokenA 和 tokenB 的顺序
        address token0 = IUniswapV2Pair(pairA).token0();
        address token1 = IUniswapV2Pair(pairA).token1();
        uint amount0Out = tokenA == token0 ? amountA : 0;
        uint amount1Out = tokenA == token1 ? amountA : 0;

        // 发起闪电贷，data 中编码 pairA 的地址
        IUniswapV2Pair(pairA).swap(amount0Out, amount1Out, address(this), abi.encode(pairA));
    }

    // Uniswap V2 回调函数，执行套利逻辑
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external override {
        // 解码 data 获取 PoolA 地址并验证调用者
        address pairA = abi.decode(data, (address));
        require(msg.sender == pairA, "Invalid sender");
        require(sender == address(this), "Not initiated by this contract");

        // 获取代币地址和借入数量
        address token0 = IUniswapV2Pair(pairA).token0();
        address token1 = IUniswapV2Pair(pairA).token1();
        address tokenA = amount0 > 0 ? token0 : token1;
        address tokenB = amount0 > 0 ? token1 : token0;
        uint amountBorrowed = amount0 > 0 ? amount0 : amount1;

        // 获取 PoolB 并确保存在
        address pairB = IUniswapV2Factory(factoryB).getPair(tokenA, tokenB);
        require(pairB != address(0), "Pair B does not exist");

        // 将借来的 tokenA 转移到 PoolB 并兑换 tokenB
        IERC20(tokenA).transfer(pairB, amountBorrowed);
        (uint reserveA0, uint reserveA1,) = IUniswapV2Pair(pairB).getReserves();
        (uint reserveIn, uint reserveOut) = tokenA == token0 ? (reserveA0, reserveA1) : (reserveA1, reserveA0);
        uint amountReceived = getAmountOut(amountBorrowed, reserveIn, reserveOut);
        (uint amount0Out, uint amount1Out) = tokenB == token0 ? (amountReceived, uint(0)) : (uint(0), amountReceived);
        IUniswapV2Pair(pairB).swap(amount0Out, amount1Out, address(this), new bytes(0));

        // 计算需要归还的 tokenB 数量
        (uint reserveB0, uint reserveB1,) = IUniswapV2Pair(pairA).getReserves();
        (reserveIn, reserveOut) = tokenB == token0 ? (reserveB0, reserveB1) : (reserveB1, reserveB0);
        uint amountRequired = getAmountIn(amountBorrowed, reserveIn, reserveOut);

        // 确保有足够的 tokenB 归还
        require(IERC20(tokenB).balanceOf(address(this)) >= amountRequired, "Insufficient profit");

        // 归还 tokenB 给 PoolA
        IERC20(tokenB).transfer(pairA, amountRequired);

        // 将利润（剩余的 tokenB）转移给调用者
        uint profit = IERC20(tokenB).balanceOf(address(this));
        IERC20(tokenB).transfer(owner, profit);
    }

    // 计算兑换输出数量（Uniswap V2 公式，含 0.3% 手续费）
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // 计算归还时需要的输入数量（Uniswap V2 公式）
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, "Insufficient output amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }
}