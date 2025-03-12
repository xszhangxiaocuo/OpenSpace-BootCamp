// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Slot/MyWallet.sol";

contract MyWalletTest is Test {
    MyWallet wallet;
    address initialOwner = address(0x1234);
    address newOwner = address(0x5678);

    function setUp() public {
        // 设置 msg.sender 为 initialOwner
        vm.prank(initialOwner);
        wallet = new MyWallet("TestWallet");
    }

    // 测试构造函数初始化
    function test_InitialOwner() public {
        assertEq(wallet.owner(), initialOwner);
        assertEq(wallet.getOwnerAssembly(), initialOwner);
    }

    // 测试名称设置
    function test_Name() public {
        assertEq(wallet.name(), "TestWallet");
    }

    // 测试只有 owner 能转移所有权
    function test_TransferOwnershipAuth() public {
        // 非 owner 尝试转移应该失败
        vm.prank(newOwner);
        vm.expectRevert("Not authorized");
        wallet.transferOwernship(newOwner);

        // owner 转移应该成功
        vm.prank(initialOwner);
        wallet.transferOwernship(newOwner);
        
        assertEq(wallet.owner(), newOwner);
        assertEq(wallet.getOwnerAssembly(), newOwner);
    }

    // 测试不能转移到零地址
    function test_TransferToZeroAddress() public {
        vm.prank(initialOwner);
        vm.expectRevert("New owner is the zero address");
        wallet.transferOwernship(address(0));
    }

    // 测试不能转移到相同地址
    function test_TransferToSameOwner() public {
        vm.prank(initialOwner);
        vm.expectRevert("New owner is the same as the old owner");
        wallet.transferOwernship(initialOwner);
    }

    // 测试汇编读取和普通读取一致性
    function test_AssemblyConsistency() public {
        assertEq(wallet.owner(), wallet.getOwnerAssembly());
        
        vm.prank(initialOwner);
        wallet.transferOwernship(newOwner);
        
        assertEq(wallet.owner(), wallet.getOwnerAssembly());
    }

    // 测试多个所有权转移
    function test_MultipleTransfers() public {
        address thirdOwner = address(0x9012);
        
        vm.prank(initialOwner);
        wallet.transferOwernship(newOwner);
        
        vm.prank(newOwner);
        wallet.transferOwernship(thirdOwner);
        
        assertEq(wallet.owner(), thirdOwner);
        assertEq(wallet.getOwnerAssembly(), thirdOwner);
    }
}