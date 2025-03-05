// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * 在以太坊上⽤ ERC20 模拟铭⽂铸造，编写一个可以通过最⼩代理来创建 ERC20 的⼯⼚合约，⼯⼚合约包含两个方法：
 *
 * • deployInscription(string symbol, uint totalSupply, uint perMint, uint price),
 *  ⽤户调⽤该⽅法创建 ERC20 Token合约，symbol 表示新创建代币的代号（ ERC20 代币名字可以使用固定的），
 *  totalSupply 表示总发行量， perMint 表示单次的创建量， price 表示每个代币铸造时需要的费用（wei 计价）。每次铸造费用在扣除手续费后（手续费请自定义）由调用该方法的用户收取。
 *
 * • mintInscription(address tokenAddr) payable: 每次调用发行创建时确定的 perMint 数量的 token，并收取相应的费用。
 *
 * 要求：
 * 包含测试用例：
 * 费用按比例正确分配到发行者账号及项目方账号。
 * 每次发行的数量正确，且不会超过 totalSupply.
 */
import "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ImpToken } from "./ImpToken.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

contract CloneFactory is Ownable {
  address public impToken;
  uint256 public feeRate = 10; // 手续费10%

  mapping(address => address[]) public allClones; // 所有代理合约
  mapping(address => address) public cloneToOwner; // 代理合约对应的创建者

  event Deployed(address indexed addr, string symbol, uint256 totalSupply, uint256 perMint, uint256 price);
  event Minted(address indexed addr, uint256 amount, uint256 price);

  constructor(address _impToken) Ownable(msg.sender) {
    impToken = _impToken;
  }

  receive() external payable { }

  // 部署最小代理合约
  function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint, uint256 price) public returns (address) {
    address addr = Clones.clone(impToken);
    allClones[msg.sender].push(addr);
    cloneToOwner[addr] = msg.sender;
    ImpToken(addr).initialize(symbol, totalSupply, perMint, price, msg.sender);

    emit Deployed(addr, symbol, totalSupply, perMint, price);
    return addr;
  }

  function mintInscription(address tokenAddr) public payable {
    ImpToken token = ImpToken(tokenAddr);
    uint256 amount = token.price() * token.perMint();
    require(msg.value >= amount, "Insufficient funds");
    uint256 fee = amount * feeRate / 100;
    payable(owner()).transfer(fee);
    // (bool success,) = payable(owner()).call{ value: fee }(""); // 项目方收取手续费
    // require(success, "Transfer failed");

    token.mint(msg.sender);
    payable(cloneToOwner[tokenAddr]).transfer(amount - fee); 
    // (success,) = payable(cloneToOwner[tokenAddr]).call{ value: amount - fee }(""); // 发行者收取铸造费用
    // require(success, "Transfer failed");
    if (msg.value > amount) {
      payable(msg.sender).transfer(msg.value - amount);
      // (success,) = payable(msg.sender).call{ value: msg.value - amount }("");
      // require(success, "Transfer failed");
    }

    emit Minted(tokenAddr, token.perMint(), token.price());
  }

  function setFeeRate(uint256 _feeRate) public onlyOwner {
    feeRate = _feeRate;
  }

  function getTokenOwner(address tokenAddr) public view returns (address) {
    return cloneToOwner[tokenAddr];
  }
}
