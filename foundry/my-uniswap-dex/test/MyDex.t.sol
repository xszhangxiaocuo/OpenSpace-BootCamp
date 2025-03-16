// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
// import "@uniswapv2-core/UniswapV2Factory.sol";
// import "@uniswapv2-core/UniswapV2Pair.sol";
import "@uniswapv2-periphery/interfaces/IUniswapV2Router02.sol";
// import "@uniswapv2-periphery/test/WETH9.sol";
import "../src/WETH9.sol";
import "../src/RNT.sol";
import "../src/MyDex.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairsLength() external view returns (uint256);
}

// interface IUniswapV2Router02 {
//     function WETH() external view returns (address);
//     function addLiquidityETH(
//         address token,
//         uint amountTokenDesired,
//         uint amountTokenMin,
//         uint amountETHMin,
//         address to,
//         uint deadline
//     ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

//     function swapExactETHForTokens(
//         uint amountOutMin,
//         address[] calldata path,
//         address to,
//         uint deadline
//     ) external payable returns (uint[] memory amounts);

//     function swapExactTokensForETH(
//         uint amountIn,
//         uint amountOutMin,
//         address[] calldata path,
//         address to,
//         uint deadline
//     ) external returns (uint[] memory amounts);
// }

contract MyDexTest is Test {
    MyDex public myDex;
    IUniswapV2Router02 public router;
    IUniswapV2Factory public factory;
    address public weth;
    RNT public rnt;

    address user;

    function setUp() public {
        vm.createSelectFork("http://127.0.0.1:8545");

        address routerAddr = vm.envAddress("ROUTER");
        address factoryAddr = vm.envAddress("FACTORY");
        weth = vm.envAddress("WETH");

        router = IUniswapV2Router02(routerAddr);
        factory = IUniswapV2Factory(factoryAddr);

        // 部署 MyDex 合约
        myDex = new MyDex(routerAddr);

        // 部署 Mock Token RNT
        rnt = new RNT("RNT", "RNT");
        user = makeAddr("user");
        rnt.transfer(user, 100_000 ether);
    }

    function test1_CreatePair_AddLiquidity() public {
        // 创建交易对
        address pair = factory.getPair(address(rnt), weth);
        if (pair == address(0)) {
            pair = factory.createPair(address(rnt), weth);
        }
        assertTrue(pair != address(0), "Pair creation failed");

        // 添加流动性
        rnt.approve(address(router), 10_000 ether);
        router.addLiquidityETH{value: 10 ether}(address(rnt), 10_000 ether, 0, 0, address(this), block.timestamp + 300);
    }

    function test2_RemoveLiquidity() public {
        // 添加流动性
        rnt.approve(address(router), 10_000 ether);
        (,, uint256 liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(rnt), 10_000 ether, 0, 0, address(this), block.timestamp + 300
        );

        // 获取 pair 合约
        address pair = factory.getPair(address(rnt), weth);
        assertTrue(pair != address(0), "Pair not found");

        // 批准 Router 移除 LP Token
        IERC20(pair).approve(address(router), liquidity);

        // 移除流动性
        router.removeLiquidityETH(address(rnt), liquidity, 0, 0, address(this), block.timestamp + 300);
    }

    function test3_SwapExactTokensForETH() public {
        // 添加流动性
        rnt.approve(address(router), 10_000 ether);
        router.addLiquidityETH{value: 10 ether}(address(rnt), 10_000 ether, 0, 0, address(this), block.timestamp + 300);

        // 用户使用 RNT 换 ETH
        vm.startPrank(user);
        rnt.approve(address(router), 1000 ether);

        address[] memory path = new address[](2);
        path[0] = address(rnt);
        path[1] = weth;

        router.swapExactTokensForETH(1000 ether, 0, path, user, block.timestamp + 300);

        vm.stopPrank();
    }

    function test4_SwapExactETHForTokens() public {
        // 添加流动性
        rnt.approve(address(router), 10_000 ether);
        router.addLiquidityETH{value: 10 ether}(address(rnt), 10_000 ether, 0, 0, address(this), block.timestamp + 300);

        // 用户使用 ETH 换 RNT
        vm.deal(user, 2 ether);
        vm.startPrank(user);

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(rnt);

        router.swapExactETHForTokens{value: 1 ether}(0, path, user, block.timestamp + 300);

        vm.stopPrank();
    }

    receive() external payable {}
}
