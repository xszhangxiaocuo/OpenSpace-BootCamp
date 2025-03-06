// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../src/upgradeContract/NFTMarketProxy.sol";
import "../src/upgradeContract/NFTMarketV1.sol";
import "../src/upgradeContract/NFTMarketV2.sol";
import "../src/BaseERC721/MyERC721.sol";
import "../src/EIP2612/MyToken.sol";

contract upgradeListTest is Test {
  NFTMarketV1 market;
  NFTMarketProxy proxy;
  MyToken myToken;
  MyERC721 nft;
  address owner;
  address newOwner;

  function setUp() public {
    NFTMarketV1 implementation = new NFTMarketV1();
    owner = vm.addr(0x123);
    vm.startPrank(owner);
    myToken = new MyToken("Hoshino", "ho");
    nft = new MyERC721();
    nft.mint(owner, "http://123.com");
    // 部署代理合约并初始化逻辑合约
    proxy = new NFTMarketProxy(address(implementation), abi.encodeCall(implementation.initialize, (owner, address(myToken), address(nft))));

    market = NFTMarketV1(address(proxy));
    vm.stopPrank();
    newOwner = vm.addr(0x456);
    emit log_address(owner);
  }

  function testDepoly() public {
    vm.startPrank(owner);
    vm.expectEmit(true, true, true, true);
    emit NFTMarketV1.NFTListed(owner, 1, 1000);
    market.list(1, 1000);
    vm.stopPrank();
  }

  // 测试升级
  function testUpgradeability() public {
    // Upgrades.upgradeProxy(address(proxy), "NFTMarketV2.sol:NFTMarketV2", "", owner);
    assertEq(market.owner(), owner);
    NFTMarketV2 nftMarket2 = new NFTMarketV2();
    vm.prank(owner);
    // proxy.call(abi.encodeCall(address(proxy).upgradeToAndCall,(address(new NFTMarketV2()), abi.encodeCall(nftMarket2.initialize, (owner, address(myToken), address(nft))))));
    // 升级合约
    (bool success,) = address(proxy).call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(nftMarket2), ""));
    require(success, "upgrade failed");
  }
}
