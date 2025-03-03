// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/Script.sol";
import { TokenBank } from "../src/Permit2/TokenBank.sol";
import { MyToken } from "../src/EIP2612/MyToken.sol";

contract TokenBankScript is Script {
  address public tokenBank;
  address public token;

  function setUp() public { 
  }

  function deploy() public {
    vm.startBroadcast();
    token = address(new MyToken("Hoshino", "ho"));
    address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    tokenBank = address(new TokenBank(address(token), permit2Address));

    console.log("Token address:", address(token));
    console.log("TokenBank address:", address(tokenBank));

    // token = 0xE188f6376fcaA542F200Fd5071420b69042CbF0D;
    // address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    // tokenBank = address(new TokenBank(token, permit2Address));
    // console.log("Token address:", tokenBank);
    vm.stopBroadcast();
  }
}
