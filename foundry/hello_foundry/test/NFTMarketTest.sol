// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
上架NFT：测试上架成功和失败情况，要求断言错误信息和上架事件。
购买NFT：测试购买成功、自己购买自己的NFT、NFT被重复购买、支付Token过多或者过少情况，要求断言错误信息和购买事件。
模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT
不可变测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓
*/

import "forge-std/Test.sol";
import "../src/BaseERC721/NFTMarket.sol";
import "../src/BaseERC20/BaseERC20.sol";

contract NFTMarketTest is Test {
  NFTMarket market;
  MyERC721 nft;
  BaseERC20 token;
  NFTMarketHandler handler;

  address buyer = address(1);
  address seller = address(2);
  uint256 tokenId = 1;
  uint256 price = 10;

  function setUp() public {
    token = new BaseERC20();
    nft = new MyERC721();
    market = new NFTMarket(address(token), address(nft));

    token.transfer(buyer, 1000);
    token.transfer(seller, 1000);

    nft.mint(seller, "this is nft");

    handler = new NFTMarketHandler(market, nft, token);
    targetContract(address(handler)); // 设置测试合约
  }

  // 验证上架成功
  function list(address _seller, uint256 _tokenId, uint256 _price) public {
    vm.expectEmit(true, true, false, false);
    emit NFTMarket.NFTListed(_seller, _tokenId, _price);
    // 验证上架事件
    vm.startPrank(_seller);
    market.list(_tokenId, _price);
    nft.approve(address(market), tokenId); // 授权
    vm.stopPrank();

    // 验证授权
    assertEq(nft.getApproved(tokenId), address(market));

    // 验证价格和拥有者
    assertEq(market.nftPrices(_tokenId), _price);
    assertEq(market.nftOwners(_tokenId), _seller);
  }

  /**
   * @notice 测试上架成功
   */
  function testList() public {
    list(seller, tokenId, price);
  }

  /**
   * @notice 测试上架失败
   */
  function testListFail() public {
    // 验证上架事件
    vm.startPrank(buyer);
    vm.expectRevert("You must own the NFT to list it");
    market.list(tokenId, price);
    vm.stopPrank();

    // 验证价格和拥有者
    assertEq(market.nftPrices(tokenId), 0);
    assertEq(market.nftOwners(tokenId), address(0));
  }

  /**
   *   @notice 测试购买成功
   *   @notice 发现NFTMarket.sol中的buyNFT方法中，合约账户调用了BaseERC20的transferFrom方法将自己的token转给seller，但是transferFrom只能由不是自己的授权账户调用，所以要调用transfer方法直接转账。
   */
  function testBuyNFT() public {
    // 上架
    list(seller, tokenId, price);
    // 验证购买事件
    vm.startPrank(buyer);
    // 验证授权转账金额事件
    vm.expectEmit(true, true, true, true);
    emit BaseERC20.Approval(buyer, address(market), price);
    token.approve(address(market), price);
    // 验证购买事件
    vm.expectEmit(true, true, false, false);
    emit NFTMarket.NFTSold(buyer, tokenId);
    market.buyNFT(tokenId, price);
    vm.stopPrank();

    // 验证market中的nft价格和拥有者
    assertEq(market.nftPrices(tokenId), 0);
    assertEq(market.nftOwners(tokenId), address(0));
    // 验证nft拥有者
    assertEq(nft.ownerOf(tokenId), buyer);
  }

  /**
   * @notice 测试通过直接转账购买NFT
   */
  function testBuyNFTDirect() public {
    // 上架
    list(seller, tokenId, price);
    // 验证购买事件
    vm.startPrank(buyer);
    token.transferWithCallback(address(market), price, abi.encodePacked(tokenId));
    vm.stopPrank();

    // 验证market中的nft价格和拥有者
    assertEq(market.nftPrices(tokenId), 0);
    assertEq(market.nftOwners(tokenId), address(0));
    // 验证nft拥有者
    assertEq(nft.ownerOf(tokenId), buyer);
  }

  /**
   * @notice 测试自己购买自己的NFT
   */
  function testBuySelfNFT() public {
    // 上架
    list(seller, tokenId, price);
    // 验证购买事件
    vm.startPrank(seller);
    vm.expectRevert("you are the owner of this nft");
    market.buyNFT(tokenId, price);
    vm.stopPrank();
  }

  /**
   * @notice 测试NFT被重复购买
   */
  function testBuyTwice() public {
    // 上架
    list(seller, tokenId, price);
    // 给market代币
    deal(address(token), address(market), 100);
    // 模拟token直接给market转账购买
    vm.startPrank(address(token));
    market.tokensReceived(buyer, price, abi.encodePacked(tokenId));
    vm.expectRevert("nft not exist");
    market.tokensReceived(buyer, price, abi.encodePacked(tokenId));
    vm.stopPrank();
  }

  /**
   * @notice 测试支付Token过多或过少
   * @notice 测试发现调用NFTMarket.tokensReceived方法时没有校验传入的token数量是否足够
   */
  function testBuyMoreOrLess() public {
    // 上架
    list(seller, tokenId, price);
    // 给market代币
    deal(address(token), address(market), price - 5);

    // 验证token不足
    vm.startPrank(address(token));
    vm.expectRevert("amount is not enough");
    market.tokensReceived(buyer, price - 5, abi.encodePacked(tokenId));
    vm.stopPrank();

    // 验证token过多
    deal(address(token), address(market), price + 5);
    vm.startPrank(address(token));
    market.tokensReceived(buyer, price + 5, abi.encodePacked(tokenId));
    assertEq(token.balanceOf(address(market)), 0);
    vm.stopPrank();
  }

  /**
   * @notice 测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT
   */
  function testFuzzy(address _buyer, uint256 _price) public {
    vm.assume(_buyer != address(0));
    vm.assume(_price >= 0.01 * 10 ** 18 && _price <= 10000 * 10 ** 18);

    // 上架
    list(seller, tokenId, _price);
    // 给market代币
    deal(address(token), address(market), _price);
    // 购买
    vm.startPrank(address(token));
    market.tokensReceived(_buyer, _price, abi.encodePacked(tokenId));
    vm.stopPrank();
  }

  /**
   * @notice 测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓
   */
  function invariant_testImmutable() public view {
    assertEq(token.balanceOf(address(market)), 0);
  }
}

contract NFTMarketHandler is Test {
  NFTMarket market;
  MyERC721 nft;
  BaseERC20 token;

  address buyer = address(1);
  address seller = address(2);
  uint256 tokenId = 1;
  uint256 price = 10;

  constructor(NFTMarket _market, MyERC721 _nft, BaseERC20 _token) {
    market = _market;
    nft = _nft;
    token = _token;
  }

  // 验证上架成功
  function list(address _seller, uint256 _tokenId, uint256 _price) public {
    vm.expectEmit(true, true, false, false);
    emit NFTMarket.NFTListed(_seller, _tokenId, _price);
    // 验证上架事件
    vm.startPrank(_seller);
    market.list(_tokenId, _price);
    nft.approve(address(market), tokenId); // 授权
    vm.stopPrank();

    // 验证授权
    assertEq(nft.getApproved(tokenId), address(market));

    // 验证价格和拥有者
    assertEq(market.nftPrices(_tokenId), _price);
    assertEq(market.nftOwners(_tokenId), _seller);
  }

  // 购买NFT
  function buyNFc(address _buyer, uint256 _price) public {
    vm.assume(_buyer != address(0));
    vm.assume(_price >= 0.01 * 10 ** 18 && _price <= 10000 * 10 ** 18);

    // 上架
    list(seller, tokenId, _price);
    // 给market代币
    deal(address(token), address(market), _price);
    // 购买
    vm.startPrank(address(token));
    market.tokensReceived(_buyer, _price, abi.encodePacked(tokenId));
    vm.stopPrank();
  }
}
