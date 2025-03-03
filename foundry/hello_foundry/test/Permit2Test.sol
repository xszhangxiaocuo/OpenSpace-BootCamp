// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";
import { MyToken } from "../src/EIP2612/MyToken.sol";
import  {permit2SigUtils} from "../src/utils/permit2Sigutils.sol";
import {MyToken} from "../src/EIP2612/MyToken.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IPermit2 } from "../src/Permit2/IPermit2.sol";
import { TokenBank } from "../src/Permit2/TokenBank.sol";

contract Permit2Test is Test {
  IPermit2 permit2Address; // 0x000000000022D473030F116dDEE9F6B43aC78BA3
  TokenBank tokenBankAddress;
  MyToken tokenAddress;
  uint256 ownerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
  uint256 spenderPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
  address owner;
  address spender;
  uint256 tokenId = 1;
  uint256 amount = 10 ether;

  permit2SigUtils PERMIT2_SIGUTILS;

  // 在测试前部署所需的合约和数据
  function setUp() public {
    vm.createSelectFork("http://127.0.0.1:8545");

    permit2Address = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    // 设置账户
    owner = vm.addr(ownerPrivateKey);
    spender = vm.addr(spenderPrivateKey);

    tokenAddress = MyToken(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
    tokenBankAddress = TokenBank(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);

    // 初始化签名工具
    PERMIT2_SIGUTILS = new permit2SigUtils(address(permit2Address));
    console.log("Token Address:", address(tokenAddress));
  }

  // 测试 permit2 是否能正确验签
  function testPermit2ValidSignature() public {
    // 用户给permit2授权
    vm.startPrank(owner);
    uint256 balance = tokenAddress.balanceOf(owner);
    console.log("balance:", balance);
    tokenAddress.approve(address(permit2Address), balance);
    vm.stopPrank();
    uint256 deadline = block.timestamp + 1000;
    uint256 nonce = 0;
    permit2SigUtils.PermitTransferFrom memory permit = permit2SigUtils.PermitTransferFrom({
      permitted: IPermit2.TokenPermissions({
        token: tokenAddress,
        amount: amount
      }),
      spender: address(tokenBankAddress),
      nonce: nonce,
      deadline: deadline
    });
    // 计算签名
    bytes32 digest = PERMIT2_SIGUTILS.getTypedDataHash(permit);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
    // bytes memory signature = abi.encodePacked(r, s, v);
    bytes memory signature = bytes.concat(r, s, bytes1(v));

    // 用owner调用tokenbank的depositWithPermit2
    vm.startPrank(owner);
    tokenBankAddress.depositWithPermit2(tokenAddress, amount, nonce, deadline, signature);
    vm.stopPrank();
    assertEq(tokenAddress.balanceOf(address(tokenBankAddress)), amount);
  }
}
