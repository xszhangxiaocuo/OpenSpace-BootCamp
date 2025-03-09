// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { AirdropMerkleNFTMarket } from "../src/AirdropMerkle/AirdropMerkleNFTMarket.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { MyERC721 } from "../src/BaseERC721/MyERC721.sol";
import { MyToken } from "../src/EIP2612/MyToken.sol";
import { tokenSigUtils } from "../src/utils/tokenSigutils.sol";
import { NFTMarketSigutils } from "../src/utils/NFTMarketSigutils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract AirdropMerkleTest is Test {
  bytes32 merkleRoot = 0xb5be513486689120e59cf1efc5048ce6f312514c133aa49cba02d6e460e7409d;
  bytes32[] merkleProof =
    [bytes32(0xe532bea76eb3f6c701b02dbfdcbc77fc6d89a3ed2c4a30bd962fbdea284716a2), bytes32(0x857adae635184742c7990e6c4f5990deb3dba32620310a05430f5350d2ca84b7)];
  AirdropMerkleNFTMarket nftMarket;
  MyERC721 nft;
  uint256 ownerPrivateKey = 0x123;
  uint256 buyerPrivateKey = 0x456;
  uint256 spenderPrivateKey = 0x789;
  address owner;
  address buyer;
  address spender;
  address tokenAddress;
  uint256 tokenId = 1;
  uint256 amount = 10 ether;
  NFTMarketSigutils public NFTMARKET_SIGUTILS;
  tokenSigUtils public TOKEN_SIGUTILS;

  function setUp() public {
    owner = vm.addr(ownerPrivateKey);
    buyer = vm.addr(buyerPrivateKey);
    spender = vm.addr(spenderPrivateKey);

    vm.startPrank(owner);
    nft = new MyERC721();
    tokenAddress = address(new MyToken("Hoshino", "ho"));
    MyToken(tokenAddress).transfer(buyer, 1000 ether);
    nftMarket = new AirdropMerkleNFTMarket(tokenAddress, address(nft), merkleRoot);
    nft.mint(spender, "this is nft");
    vm.stopPrank();

    vm.startPrank(spender);
    nft.setApprovalForAll(address(nftMarket), true);
    nftMarket.list(1, amount);
    vm.stopPrank();

    NFTMARKET_SIGUTILS = new NFTMarketSigutils(address(nftMarket));
    TOKEN_SIGUTILS = new tokenSigUtils(tokenAddress);
  }

  function testMulticall() public {
    bytes[] memory data = new bytes[](2);

    // 构造permit签名
    uint256 deadline = block.timestamp + 1000;
    uint256 nonce = IERC20Permit(tokenAddress).nonces(buyer);
    tokenSigUtils.Permit memory permitData = tokenSigUtils.Permit({ owner: buyer, spender: address(nftMarket), value: amount, nonce: nonce, deadline: deadline });
    bytes32 digest = TOKEN_SIGUTILS.getTypedDataHash(permitData);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, digest);

    AirdropMerkleNFTMarket.TokenPermitData memory tokenPermitData =
      AirdropMerkleNFTMarket.TokenPermitData({ owner: buyer, spender: address(nftMarket), amount: amount, nonce: nonce, deadline: deadline });

    AirdropMerkleNFTMarket.Signature memory signature = AirdropMerkleNFTMarket.Signature({ v: v, r: r, s: s });

    // 先调用permitPrePay
    data[0] = abi.encodeWithSelector(AirdropMerkleNFTMarket.permitPrePay.selector, tokenPermitData, signature);

    // 后调用claimNFT
    data[1] = abi.encodeWithSelector(AirdropMerkleNFTMarket.claimNFT.selector, merkleProof, tokenId, amount);

    vm.prank(buyer);
    nftMarket.multicall(data);
    assertEq(nft.ownerOf(tokenId), buyer);
    assertEq(IERC20(tokenAddress).balanceOf(spender), amount);
  }
}
