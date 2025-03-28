// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";
import { NFTMarket } from "../src/EIP2612/NFTMarket.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { MyERC721 } from "../src/BaseERC721/MyERC721.sol";
import { MyToken } from "../src/EIP2612/MyToken.sol";
import { tokenSigUtils } from "../src/utils/tokenSigutils.sol";
import { NFTMarketSigutils } from "../src/utils/NFTMarketSigutils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract NFTMarketTest1 is Test {
  NFTMarket nftMarket;
  MyERC721 nft;
  uint256 ownerPrivateKey = 0x123;
  uint256 buyerPrivateKey = 0x456;
  uint256 spenderPrivateKey = 0x789;
  address owner;
  address buyer;
  address spender;
  address tokenAddress;
  uint256 tokenId = 1;
  uint256 amount = 1000 ether;
  NFTMarketSigutils public NFTMARKET_SIGUTILS;
  tokenSigUtils public TOKEN_SIGUTILS;
  // 在测试前部署所需的合约和数据

  function setUp() public {
    // 设置账户
    owner = vm.addr(ownerPrivateKey);
    buyer = vm.addr(buyerPrivateKey);
    spender = vm.addr(spenderPrivateKey);

    // 部署 Token 和 NFT 合约
    vm.startPrank(owner);
    tokenAddress = address(new MyToken("Hoshino", "ho"));
    nft = new MyERC721();
    IERC20(tokenAddress).transfer(buyer, 1000 ether);
    assertEq(IERC20(tokenAddress).balanceOf(buyer), 1000 ether);

    // 部署 NFTMarket 合约
    nftMarket = new NFTMarket(tokenAddress, address(nft));

    // 添加一个 NFT，上架，并给 NFTMarket 合约授权
    nft.mint(spender, "https://hoshino.io");
    assertEq(nft.ownerOf(tokenId), spender);
    vm.stopPrank();

    vm.startPrank(spender);
    nftMarket.list(tokenId, 100 ether); // 定价为 100 token
    nft.approve(address(nftMarket), tokenId);
    assertEq(nftMarket.getNFTPrice(tokenId), 100 ether);
    assertEq(nftMarket.getNFTOwner(tokenId), spender);
    vm.stopPrank();

    vm.deal(buyer, 1000 ether);

    // 初始化签名工具
    NFTMARKET_SIGUTILS = new NFTMarketSigutils(address(nftMarket));
    TOKEN_SIGUTILS = new tokenSigUtils(tokenAddress);
  }

  // 测试 permitBuy 是否能正确验签
  function testPermitBuyValidSignature() public {
    // 创建 PermitData 和 TokenPermitData 数据
    uint256 deadline = block.timestamp + 1 days;
    uint256 nonce = nftMarket.getPermitNonce(buyer);
    uint256 buyerNonce = IERC20Permit(tokenAddress).nonces(buyer);
    NFTMarket.PermitData memory permitData = NFTMarket.PermitData({ buyer: buyer, tokenId: tokenId, amount: 100 ether, nonce: nonce, deadline: deadline });
    NFTMarket.TokenPermitData memory tokenPermitData =
      NFTMarket.TokenPermitData({ owner: buyer, spender: address(nftMarket), amount: 100 ether, nonce: buyerNonce, deadline: deadline });

    // 构建白名单签名数据
    NFTMarket.Signature[] memory signatures = new NFTMarket.Signature[](2);
    bytes32 digest = NFTMARKET_SIGUTILS.getTypedDataHash(
      NFTMarketSigutils.Permit({ buyer: permitData.buyer, tokenId: permitData.tokenId, value: permitData.amount, nonce: permitData.nonce, deadline: permitData.deadline })
    );

    (signatures[0].v, signatures[0].r, signatures[0].s) = vm.sign(ownerPrivateKey, digest);
    address recovered = ecrecover(digest, signatures[0].v, signatures[0].r, signatures[0].s);
    assertEq(recovered, owner);
    // keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(PERMIT_TYPEHASH, permitData.buyer, permitData.tokenId, permitData.amount,_useNonce(permitData.buyer), permitData.deadline))))
    // 对 ERC20 的 permit 签名进行模拟
    digest = TOKEN_SIGUTILS.getTypedDataHash(tokenSigUtils.Permit({ owner: buyer, spender: address(nftMarket), value: 100 ether, nonce: buyerNonce, deadline: deadline }));
    (signatures[1].v, signatures[1].r, signatures[1].s) = vm.sign(buyerPrivateKey, digest);

    // 执行 permitBuy
    vm.startPrank(buyer);
    vm.expectEmit(true, true, false, true);
    emit NFTMarket.NFTSold(buyer, tokenId);
    nftMarket.permitBuy(permitData, tokenPermitData, signatures);
    vm.stopPrank();
    assertEq(nft.ownerOf(tokenId), buyer);
    // assertEq(IERC20(tokenAddress).balanceOf(spender), 100 ether);
    assertEq(IERC20(tokenAddress).balanceOf(buyer), 900 ether);
  }

  // 测试 permitBuyWithOwnerSignature 是否能正确验签，使用token购买
  function testPermitBuyWithOwnerSignatureValidSignature() public {
    // 创建 PermitData 和 TokenPermitData 数据
    uint256 deadline = block.timestamp + 1 days;
    uint256 nonce = nftMarket.getPermitNonce(buyer);
    uint256 buyerNonce = IERC20Permit(tokenAddress).nonces(buyer);
    NFTMarket.PermitData memory permitData = NFTMarket.PermitData({ buyer: buyer, tokenId: tokenId, amount: 100 ether, nonce: nonce, deadline: deadline });
    NFTMarket.TokenPermitData memory tokenPermitData =
      NFTMarket.TokenPermitData({ owner: buyer, spender: address(nftMarket), amount: 100 ether, nonce: buyerNonce, deadline: deadline });
    NFTMarket.ListPermitData memory listPermitData = NFTMarket.ListPermitData({ seller: spender, tokenId: tokenId, price: 100 ether, deadline: deadline });

    // 构建上架签名数据
    NFTMarket.Signature[] memory signatures = new NFTMarket.Signature[](3);
    bytes32 digest = NFTMARKET_SIGUTILS.getListTypedDataHash(
      NFTMarketSigutils.ListPermit({ seller: listPermitData.seller, tokenId: listPermitData.tokenId, price: listPermitData.price, deadline: listPermitData.deadline })
    );

    (signatures[0].v, signatures[0].r, signatures[0].s) = vm.sign(spenderPrivateKey, digest);
    address recovered = ecrecover(digest, signatures[0].v, signatures[0].r, signatures[0].s);
    assertEq(recovered, spender);

    // 构建白名单签名数据
    digest = NFTMARKET_SIGUTILS.getTypedDataHash(
      NFTMarketSigutils.Permit({ buyer: permitData.buyer, tokenId: permitData.tokenId, value: permitData.amount, nonce: permitData.nonce, deadline: permitData.deadline })
    );

    (signatures[1].v, signatures[1].r, signatures[1].s) = vm.sign(ownerPrivateKey, digest);
    recovered = ecrecover(digest, signatures[1].v, signatures[1].r, signatures[1].s);
    assertEq(recovered, owner);
    // keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(PERMIT_TYPEHASH, permitData.buyer, permitData.tokenId, permitData.amount,_useNonce(permitData.buyer), permitData.deadline))))
    // 对 ERC20 的 permit 签名进行模拟
    digest = TOKEN_SIGUTILS.getTypedDataHash(tokenSigUtils.Permit({ owner: buyer, spender: address(nftMarket), value: 100 ether, nonce: buyerNonce, deadline: deadline }));
    (signatures[2].v, signatures[2].r, signatures[2].s) = vm.sign(buyerPrivateKey, digest);

    // 执行 permitBuyWithOwnerSignature
    vm.startPrank(buyer);
    vm.expectEmit(true, true, false, true);
    emit NFTMarket.NFTSold(buyer, tokenId);
    NFTMarket.PermitBuyWithOwnerSignatureParams memory params =
      NFTMarket.PermitBuyWithOwnerSignatureParams({ listPermitData: listPermitData, permitData: permitData, tokenPermitData: tokenPermitData, signature: signatures });
    nftMarket.permitBuyWithOwnerSignature(params, true);
    vm.stopPrank();
    assertEq(nft.ownerOf(tokenId), buyer);
    // assertEq(IERC20(tokenAddress).balanceOf(spender), 100 ether);
    assertEq(IERC20(tokenAddress).balanceOf(buyer), 900 ether);
  }

  // 测试 permitBuyWithOwnerSignature 是否能正确验签，使用ETH购买
  function testPermitBuyWithOwnerSignatureValidSignatureByETH() public {
    // 创建 PermitData 和 TokenPermitData 数据
    uint256 deadline = block.timestamp + 1 days;
    uint256 nonce = nftMarket.getPermitNonce(buyer);
    uint256 buyerNonce = IERC20Permit(tokenAddress).nonces(buyer);
    NFTMarket.PermitData memory permitData = NFTMarket.PermitData({ buyer: buyer, tokenId: tokenId, amount: 100 ether, nonce: nonce, deadline: deadline });
    NFTMarket.TokenPermitData memory tokenPermitData =
      NFTMarket.TokenPermitData({ owner: buyer, spender: address(nftMarket), amount: 100 ether, nonce: buyerNonce, deadline: deadline });
    NFTMarket.ListPermitData memory listPermitData = NFTMarket.ListPermitData({ seller: spender, tokenId: tokenId, price: 100 ether, deadline: deadline });

    // 构建上架签名数据
    NFTMarket.Signature[] memory signatures = new NFTMarket.Signature[](3);
    bytes32 digest = NFTMARKET_SIGUTILS.getListTypedDataHash(
      NFTMarketSigutils.ListPermit({ seller: listPermitData.seller, tokenId: listPermitData.tokenId, price: listPermitData.price, deadline: listPermitData.deadline })
    );

    (signatures[0].v, signatures[0].r, signatures[0].s) = vm.sign(spenderPrivateKey, digest);
    address recovered = ecrecover(digest, signatures[0].v, signatures[0].r, signatures[0].s);
    assertEq(recovered, spender);

    // 构建白名单签名数据
    digest = NFTMARKET_SIGUTILS.getTypedDataHash(
      NFTMarketSigutils.Permit({ buyer: permitData.buyer, tokenId: permitData.tokenId, value: permitData.amount, nonce: permitData.nonce, deadline: permitData.deadline })
    );

    (signatures[1].v, signatures[1].r, signatures[1].s) = vm.sign(ownerPrivateKey, digest);
    recovered = ecrecover(digest, signatures[1].v, signatures[1].r, signatures[1].s);
    assertEq(recovered, owner);
    // keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(PERMIT_TYPEHASH, permitData.buyer, permitData.tokenId, permitData.amount,_useNonce(permitData.buyer), permitData.deadline))))
    // 对 ERC20 的 permit 签名进行模拟
    digest = TOKEN_SIGUTILS.getTypedDataHash(tokenSigUtils.Permit({ owner: buyer, spender: address(nftMarket), value: 100 ether, nonce: buyerNonce, deadline: deadline }));
    (signatures[2].v, signatures[2].r, signatures[2].s) = vm.sign(buyerPrivateKey, digest);

    // 执行 permitBuyWithOwnerSignature
    vm.startPrank(buyer);
    vm.expectEmit(true, true, false, true);
    emit NFTMarket.NFTSold(buyer, tokenId);
    NFTMarket.PermitBuyWithOwnerSignatureParams memory params =
      NFTMarket.PermitBuyWithOwnerSignatureParams({ listPermitData: listPermitData, permitData: permitData, tokenPermitData: tokenPermitData, signature: signatures });
    nftMarket.permitBuyWithOwnerSignature{ value: 100 ether }(params, false);
    vm.stopPrank();
    assertEq(nft.ownerOf(tokenId), buyer);
    assertEq(spender.balance, 100 ether);
  }

  // 测试取消订单
  function testCancelOrder() public {
    uint256 deadline = block.timestamp + 1 days;
    NFTMarket.ListPermitData memory listPermitData = NFTMarket.ListPermitData({ seller: spender, tokenId: tokenId, price: 100 ether, deadline: deadline });
    // 构建上架签名数据
    NFTMarket.Signature memory signatures;
    bytes32 digest = NFTMARKET_SIGUTILS.getListTypedDataHash(
      NFTMarketSigutils.ListPermit({ seller: listPermitData.seller, tokenId: listPermitData.tokenId, price: listPermitData.price, deadline: listPermitData.deadline })
    );

    (signatures.v, signatures.r, signatures.s) = vm.sign(spenderPrivateKey, digest);
    address recovered = ecrecover(digest, signatures.v, signatures.r, signatures.s);
    assertEq(recovered, spender);

    // 执行 cancelOrder
    vm.startPrank(spender);
    vm.expectEmit(true, true, false, true);
    emit NFTMarket.OrderCanceled(spender, tokenId);
    nftMarket.cancelOrder(listPermitData,signatures);
    vm.stopPrank();
  }

  function testGasConsumption() public {
    vm.startPrank(spender);

    // 开始记录 gas
    uint256 gasStart = gasleft();

    // 目标代码行
    nft.approve(address(nftMarket), tokenId);

    // 结束记录 gas
    uint256 gasUsed = gasStart - gasleft();

    vm.stopPrank();

    // 输出 gas 消耗
    console.log("Gas used for nft.approve:", gasUsed);
  }
}
