// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MinimalProxy/CloneFactory.sol";
import "../src/MinimalProxy/ImpToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MinimalProxyTest is Test {
  CloneFactory factory;
  ImpToken impToken;
  // address owner = address(0x1);
  // address tokenOwner = address(0x2);
  // address minter = address(0x3);
  address owner;
  address tokenOwner;
  address minter;
  uint256 k1;
  uint256 k2;
  uint256 k3;
  uint256 public platformFeePercentage = 10; // 平台收取10%手续费
  uint256 public mintPrice = 1;
  uint256 public perMint = 10 * 10 ** 18;
  uint256 public totalSupply = 20 * 10 ** 18;

  function setUp() public {
    (owner,k1) = makeAddrAndKey("owner");
    (tokenOwner,k2) = makeAddrAndKey("tokenOwner");
    (minter,k3)= makeAddrAndKey("minter");
    vm.startPrank(owner);
    impToken = new ImpToken();
    factory = new CloneFactory(address(impToken));
    vm.stopPrank();
    vm.deal(minter, 1000 ether);
  }

  // 测试部署一个最小代理合约
  function testDeployInscription() public {
    vm.prank(tokenOwner);
    address tokenAddr = factory.deployInscription("MyToken", totalSupply, perMint, mintPrice);

    assert(tokenAddr != address(0));
    assertEq(factory.getTokenOwner(tokenAddr), tokenOwner);
  }

  // 测试铸造代币
  function testMintInscription() public {
    vm.prank(tokenOwner);
    address tokenAddr = factory.deployInscription("MyToken", totalSupply, perMint, mintPrice);
    ImpToken token = ImpToken(tokenAddr);
    uint256 amount = mintPrice * perMint;
    vm.prank(minter);

    factory.mintInscription{ value: amount }(tokenAddr);

    // 确保用户得到正确数量的 token
    assertEq(token.balanceOf(minter), perMint);

    // 检查费用分配
    uint256 platformAmount = amount * platformFeePercentage / 100;
    uint256 tokenOwnerAmount = amount - platformAmount;

    assertEq(tokenOwner.balance, tokenOwnerAmount);
    assertEq(factory.owner().balance, platformAmount);
  }

  // 测试不能超过总发行量
  function testMintBeyond() public {
    vm.prank(tokenOwner);
    address tokenAddr = factory.deployInscription("MyToken", totalSupply, perMint, mintPrice);
    ImpToken token = ImpToken(tokenAddr);
    uint256 amount = mintPrice * perMint;

    vm.startPrank(minter);
    factory.mintInscription{ value: amount }(tokenAddr);
    factory.mintInscription{ value: amount }(tokenAddr);
    vm.expectRevert("ImpToken: exceeds max supply");
    factory.mintInscription{ value: amount }(tokenAddr);
    vm.stopPrank();

    uint256 platformAmount = amount * platformFeePercentage / 100;
    uint256 tokenOwnerAmount = amount - platformAmount;
    assertEq(token.totalSupply(), totalSupply);
    assertEq(tokenOwner.balance, 2 * tokenOwnerAmount);
    assertEq(factory.owner().balance, 2 * platformAmount);
  }
}
