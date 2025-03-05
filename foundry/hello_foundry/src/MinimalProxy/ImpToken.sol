// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// 逻辑合约 implementation
contract ImpToken is ERC20 {
  address public owner;
  bool public initialized;
  string public tokenName="Hoshino";
  string public tokenSymbol;
  uint256 public maxSupply;
  uint256 public perMint;
  uint256 public price;

  constructor() ERC20("", "") {
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "ImpToken: not owner");
    _;
  }

  function initialize(string calldata _symbol, uint256 _totalSupply, uint256 _perMint, uint256 _price, address _owner) external {
    require(!initialized, "ImpToken: already initialized");
    require(owner == address(0), "ImpToken: owner is not 0");
    initialized = true;
    tokenSymbol = _symbol;
    owner = _owner;
    maxSupply = _totalSupply;
    perMint = _perMint;
    price = _price;
  }

  function mint(address to) external {
    require(totalSupply() + perMint <= maxSupply, "ImpToken: exceeds max supply");
    _mint(to, perMint);
  }
}
