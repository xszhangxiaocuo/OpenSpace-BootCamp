// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/Script.sol";
import { TokenBank } from "../src/EIP2612/TokenBank.sol";

contract TokenBankScript is Script {
  TokenBank public tokenBank;

  function setUp() public { }

  function deploy() public {
    address tokenAddress = 0xE188f6376fcaA542F200Fd5071420b69042CbF0D;
    vm.startBroadcast();
    {
      tokenBank = new TokenBank(address(tokenAddress));
      
      console.log("Token address:", address(tokenBank));

    }
    vm.stopBroadcast();
  }
}
