// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswapv2-periphery/interfaces/IUniswapV2Router02.sol";

interface IDex {
    function sellETH(address buyToken, uint256 minBuyAmount) external payable;
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external;
}

contract MyDex is IDex {
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public immutable uniswapRouter;
    address public immutable WETH;

    constructor(address _uniswapRouter) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        WETH = uniswapRouter.WETH();
    }

    function sellETH(address buyToken, uint256 minBuyAmount) external payable override {
        require(msg.value > 0, "No ETH sent");

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = buyToken;

        uniswapRouter.swapExactETHForTokens{value: msg.value}(minBuyAmount, path, msg.sender, block.timestamp + 300);
    }

    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external override {
        require(sellAmount > 0, "Invalid amount");

        IERC20 token = IERC20(sellToken);

        token.safeTransferFrom(msg.sender, address(this), sellAmount);
        token.approve(address(uniswapRouter), sellAmount);

        address[] memory path = new address[](2);
        path[0] = sellToken;
        path[1] = WETH;

        uniswapRouter.swapExactTokensForETH(sellAmount, minBuyAmount, path, msg.sender, block.timestamp + 300);
    }

    receive() external payable {}
}
