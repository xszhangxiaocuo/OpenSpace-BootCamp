// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/Script.sol";
import "../src/upgradeContract/NFTMarketProxy.sol";
import "../src/upgradeContract/NFTMarketV1.sol";
import "../src/upgradeContract/NFTMarketV2.sol";

contract TokenBankScript is Script {
  NFTMarketV1 public nftMarket;
  NFTMarketProxy public proxy;

  function setUp() public { }

  function deploy() public {
    address tokenAddress = 0xE188f6376fcaA542F200Fd5071420b69042CbF0D;
    address nftAddress = 0x07D3130751B589fD46133deB1E0c67D5D4626922;
    address deployer = 0x7df01af4c8f6D985970625f0264b5F932a24c6A4;
    vm.startBroadcast(deployer);
    {
      nftMarket = new NFTMarketV1();
      proxy = new NFTMarketProxy(address(nftMarket), abi.encodeWithSignature("initialize(address,address,address)", deployer,tokenAddress, nftAddress));
      console.log("market1 address:", address(nftMarket));
      console.log("proxy address:", address(proxy));

      NFTMarketV2 nftMarket2 = new NFTMarketV2();
      (bool success,) = address(proxy).call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(nftMarket2), ""));
      require(success, "upgrade failed");
      console.log("market2 address:", address(nftMarket2));
    }
    vm.stopBroadcast();
  }
}
