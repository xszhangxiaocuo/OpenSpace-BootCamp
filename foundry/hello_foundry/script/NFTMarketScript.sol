// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/Script.sol";
import { NFTMarket } from "../src/EIP2612/NFTMarket.sol";

contract TokenBankScript is Script {
  NFTMarket public nftMarket;

  function setUp() public { }

  function deploy() public {
    address tokenAddress = 0xE188f6376fcaA542F200Fd5071420b69042CbF0D;
    address nftAddress = 0x07D3130751B589fD46133deB1E0c67D5D4626922;

    vm.startBroadcast();
    {
      nftMarket = new NFTMarket(tokenAddress, nftAddress);
      console.log("Token address:", address(nftMarket));

    }
    vm.stopBroadcast();
  }
}
