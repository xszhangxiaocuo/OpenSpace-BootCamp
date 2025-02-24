// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultiSigWallet/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
  MultiSigWallet wallet;

  address owner1 = address(0x1);
  address owner2 = address(0x2);
  address owner3 = address(0x3);
  address nonOwner = address(0x4);
  address to = address(0x5);

  function setUp() public {
    // 部署合约，设定三个所有者和2个确认的门槛
    address[] memory owners = new address[](3);
    owners[0] = owner1;
    owners[1] = owner2;
    owners[2] = owner3;

    wallet = new MultiSigWallet(owners, 2);
  }

  // 测试钱包创建是否成功
  function testDeploy() public view {
    assertEq(wallet.required(), 2);
    assertEq(wallet.owners(0), owner1);
    assertEq(wallet.owners(1), owner2);
    assertEq(wallet.owners(2), owner3);
  }

  // 测试提案的创建
  function testSubmitProposal() public {
    vm.deal(address(wallet), 10 ether);
    uint256 initialProposalCount = wallet.proposalCount();

    vm.expectEmit(true, false, false, true);
    emit MultiSigWallet.ProposalCreated(initialProposalCount + 1, to, 1 ether, "");

    vm.startPrank(owner1);
    uint256 proposalCount = wallet.submitProposal(to, 1 ether, "");
    assertEq(proposalCount, initialProposalCount + 1);
    vm.stopPrank();
  }

  // 测试提案确认功能
  function testConfirmProposal() public {
    vm.startPrank(owner1);
    uint256 proposalId = wallet.submitProposal(to, 1, "");
    vm.stopPrank();

    vm.deal(address(wallet), 10 ether);

    vm.startPrank(owner2);
    vm.expectEmit(true, true, false, true);
    emit MultiSigWallet.ProposalConfirmed(proposalId, owner2);
    wallet.confirmProposal(proposalId);
    vm.stopPrank();

    // 确认签名计数增加
    uint256 confirmCount = wallet.getConfirmed(proposalId);
    assertEq(confirmCount, 2);

    // 测试第二个持有者确认提案
    bool isConfirmed = wallet.getIsConfirmed(proposalId, owner2);
    assertTrue(isConfirmed);
    // 测试重复确认
    vm.startPrank(owner2);
    vm.expectRevert("you already confirmed");
    wallet.confirmProposal(proposalId);
    vm.stopPrank();
  }

  // 测试执行提案
  function testExecuteProposal() public {
    vm.startPrank(owner1);
    uint256 proposalId = wallet.submitProposal(to, 1 ether, "");
    vm.stopPrank();

    vm.deal(address(wallet), 10 ether);

    vm.startPrank(owner3);
    vm.expectEmit(true, true, false, true);
    emit MultiSigWallet.ProposalConfirmed(proposalId, owner3);
    wallet.confirmProposal(proposalId);
    vm.stopPrank();

    // 确保提案已执行
    bool executed = wallet.getExecuted(proposalId);
    assertTrue(executed);
  }

  // 测试非持有人无法提交提案
  function testNonOwnerCannotSubmit() public {
    vm.deal(address(wallet), 10 ether);

    // 非持有人尝试执行提案
    vm.prank(nonOwner);
    vm.expectRevert("only owner");
    wallet.submitProposal(to, 1 ether, "");
  }

  // 测试非持有人无法确认提案
  function testNonOwnerCannotConfirm() public {
    vm.deal(address(wallet), 10 ether);
    vm.startPrank(owner1);
    uint256 proposalId = wallet.submitProposal(to, 1 ether, "");
    vm.stopPrank();

    // 非持有人尝试执行提案
    vm.prank(nonOwner);
    vm.expectRevert("only owner");
    wallet.confirmProposal(proposalId);
  }

  // 测试非持有人无法执行提案
  function testNonOwnerCannotExecute() public {
    vm.deal(address(wallet), 10 ether);
    vm.startPrank(owner1);
    uint256 proposalId = wallet.submitProposal(to, 1 ether, "");
    vm.stopPrank();

    // 非持有人尝试执行提案
    vm.prank(nonOwner);
    vm.expectRevert("only owner");
    wallet.executeProposal(proposalId);
  }
}
