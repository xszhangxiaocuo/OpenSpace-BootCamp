// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/MyToken.sol";
import "../src/FlashSwap.sol";

contract PoolInitTest is Test {
    IUniswapV2Factory public factory1; // DEX1 的工厂
    IUniswapV2Factory public factory2; // DEX2 的工厂
    IUniswapV2Router02 public router1; // DEX1 的路由器
    IUniswapV2Router02 public router2; // DEX2 的路由器
    IERC20 public tokenA; // 代币 A
    IERC20 public tokenB; // 代币 B
    FlashSwap public flashSwap; // 闪电贷合约

    address public owner = address(this);
    address public user = address(0x123);
    address public weth; // 模拟的 WETH 地址

    function setUp() public {
        vm.createSelectFork("http://localhost:8545");

        // 部署的 WETH（测试环境）
        weth = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0; 

        // 部署两个 Uniswap V2 工厂
        factory1 = IUniswapV2Factory(address(0x5FbDB2315678afecb367f032d93F642f64180aa3));
        factory2 = IUniswapV2Factory(address(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512));

        // 部署两个 Uniswap V2 路由器
        router1 = IUniswapV2Router02(address(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9));
        router2 = IUniswapV2Router02(address(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707));

        // 部署两个 ERC20 代币
        tokenA = new MyToken("MyTokenA","MTA");
        tokenB = new MyToken("MyTokenB","MTB");

        // 部署闪电贷合约
        flashSwap = new FlashSwap(address(factory1), address(factory2));

        tokenA.approve(address(flashSwap), type(uint256).max);
        tokenB.approve(address(flashSwap), type(uint256).max);

        // 初始化 PoolA（DEX1）
        factory1.createPair(address(tokenA), address(tokenB));
        address poolA = factory1.getPair(address(tokenA), address(tokenB));
        // 为 PoolA 添加流动性：1000 TokenA + 100 TokenB
        tokenA.approve(address(router1), 1e10 * 10**18);
        tokenB.approve(address(router1), 100 * 10**18);
        router1.addLiquidity(
            address(tokenA),
            address(tokenB),
            1e10 * 10**18, // 1000 TokenA
            100 * 10**18,  // 100 TokenB
            0,
            0,
            owner,
            block.timestamp + 1000
        );

        // 初始化 PoolB（DEX2）
        factory2.createPair(address(tokenA), address(tokenB));
        address poolB = factory2.getPair(address(tokenA), address(tokenB));
        // 为 PoolB 添加流动性：500 TokenA + 1000 TokenB
        tokenA.approve(address(router2), 500 * 10**18);
        tokenB.approve(address(router2), 1e10 * 10**18);
        router2.addLiquidity(
            address(tokenA),
            address(tokenB),
            500 * 10**18,  // 500 TokenA
            1e10 * 10**18, // 1000 TokenB
            0,
            0,
            owner,
            block.timestamp + 1000
        );
    }


    function testFlashSwapSuccess() public {
        // 记录闪电兑换合约初始余额
        uint initialBalanceA = tokenA.balanceOf(address(flashSwap));
        // uint initialBalanceB = tokenB.balanceOf(address(flashSwap));
        uint initialBalanceOwner = tokenB.balanceOf(user);

        // 设置借入数量（根据池子储备量调整）
        uint amountToBorrow = 9e9 * 10**18; // 借入 10 个 TokenA

        // 执行闪电兑换
        vm.prank(user);
        flashSwap.startFlashSwap(address(tokenA), address(tokenB), amountToBorrow);

        // 记录闪电兑换后的余额
        uint finalBalanceA = tokenA.balanceOf(address(flashSwap));
        // uint finalBalanceB = tokenB.balanceOf(address(flashSwap));
        uint finalBalanceOwner = tokenB.balanceOf(user);

        // 断言验证
        // 1. TokenA 余额应保持不变（借入并归还）
        assertEq(finalBalanceA, initialBalanceA, "TokenA balance should not change");
        // 2. TokenB 余额应增加（套利利润）
        // assertGt(finalBalanceB, initialBalanceB, "No profit made in TokenB");
        // 3. 合约所有者的 TokenA 余额应增加（套利利润）
        assertGt(finalBalanceOwner, initialBalanceOwner, "No profit made for user");
    }
}