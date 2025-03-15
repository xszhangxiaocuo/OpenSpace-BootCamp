// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IDex {
    /**
     * @dev 卖出ETH，兑换成 buyToken
     *      msg.value 为出售的ETH数量
     * @param buyToken 兑换的目标代币地址
     * @param minBuyAmount 要求最低兑换到的 buyToken 数量
     */
    function sellETH(address buyToken, uint256 minBuyAmount) external payable;

    /**
     * @dev 买入ETH，用 sellToken 兑换
     * @param sellToken 出售的代币地址
     * @param sellAmount 出售的代币数量
     * @param minBuyAmount 要求最低兑换到的ETH数量
     */
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external;
}

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function WETH() external view returns (address);
}

contract MyDex is IDex {
    using SafeERC20 for IERC20;

    IUniswapV2Router public immutable uniswapRouter;
    address public immutable WETH;

    constructor(address _uniswapRouter) {
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
        WETH = uniswapRouter.WETH();
    }

    /**
     * 卖出 ETH，兑换为指定代币
     */
    function sellETH(address buyToken, uint256 minBuyAmount) external payable override {
        require(msg.value > 0, "No ETH sent");

        address;
        path[0] = WETH;
        path[1] = buyToken;

        uniswapRouter.swapExactETHForTokens{value: msg.value}(
            minBuyAmount,
            path,
            msg.sender,
            block.timestamp + 300
        );
    }

    /**
     * 买入 ETH，使用 sellToken 兑换
     */
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external override {
        require(sellAmount > 0, "Invalid amount");

        IERC20 token = IERC20(sellToken);

        // 用户先 approve 给 MyDex 合约，然后我们使用 transferFrom 拉过来
        token.safeTransferFrom(msg.sender, address(this), sellAmount);

        // 授权给 Uniswap Router
        token.safeApprove(address(uniswapRouter), sellAmount);

        address;
        path[0] = sellToken;
        path[1] = WETH;

        uniswapRouter.swapExactTokensForETH(
            sellAmount,
            minBuyAmount,
            path,
            msg.sender,
            block.timestamp + 300
        );
    }

    // 接收 ETH fallback
    receive() external payable {}
}