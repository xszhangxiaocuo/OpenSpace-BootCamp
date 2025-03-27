// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CallOptionToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdt;         // USDT token address
    uint256 public immutable strikePrice; // USDT per 1 ETH (e.g., 1800 * 1e6)
    uint256 public immutable expiry;      // Expiry timestamp (unix)
    address public immutable treasury;    // Where USDT goes after exercise

    bool public expired;                  // Whether expired() has been called

    constructor(
        address _usdt,
        uint256 _strikePrice,
        uint256 _expiry
    ) ERC20("Call Option ETH", "oETH") Ownable(msg.sender) {
        require(_usdt != address(0), "Invalid USDT address");
        require(_strikePrice > 0, "Strike price must be > 0");
        require(_expiry > block.timestamp, "Expiry must be in the future");

        usdt = IERC20(_usdt);
        strikePrice = _strikePrice;
        expiry = _expiry;
        treasury = msg.sender;
    }

    /// @notice Mint Option Token by depositing ETH
    function mintOption() external payable {
        require(block.timestamp < expiry, "Option expired");
        require(msg.value > 0, "No ETH sent");
        _mint(msg.sender, msg.value); // 1 ETH = 1 oETH
    }

    /// @notice Exercise option on expiry date by paying USDT to receive ETH
    function exercise(uint256 amount) external {
        require(block.timestamp >= expiry && block.timestamp < expiry + 1 days, "Not exercisable now");
        require(balanceOf(msg.sender) >= amount, "Not enough options");

        _burn(msg.sender, amount);

        uint256 cost = amount * strikePrice / 1e18; // USDT has 6 decimals
        usdt.safeTransferFrom(msg.sender, treasury, cost);
        payable(msg.sender).transfer(amount);
    }

    /// @notice Expire option: destroy leftover ETH and mark as expired
    function expire() external onlyOwner {
        require(block.timestamp >= expiry + 1 days, "Too early to expire");
        require(!expired, "Already expired");

        expired = true;
        payable(treasury).transfer(address(this).balance);
    }

    /// @notice Get remaining time until expiry (for frontend)
    function timeToExpiry() external view returns (uint256) {
        if (block.timestamp >= expiry) return 0;
        return expiry - block.timestamp;
    }

    receive() external payable {
        revert("Use mintOption()");
    }
}