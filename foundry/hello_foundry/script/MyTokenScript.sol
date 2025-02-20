// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/Script.sol";
import { MyToken } from "../src/MyToken.sol";

contract MyTokenScript is Script {
  MyToken public token;

  function setUp() public { }

  function deploy() public {
    string memory _name = "Hoshino";
    string memory _symbol = "ho";
    vm.startBroadcast();
    {
      token = new MyToken(_name, _symbol);

      console.log("Token address:", address(token));
      console.log("Token name:", token.name());
      console.log("Token symbol:", token.symbol());
      console.log("Token total supply:", token.totalSupply());

      address xszxc = makeAddr("xszxc");
      console.log("xszxc address:", xszxc);
      token.transfer(xszxc, 1e18);
      console.log("xszxc balance:", token.balanceOf(xszxc));
    }
    vm.stopBroadcast();
  }
}
