// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
编写一个简单的 NFTMarket 合约，使用自己发行的ERC20 扩展 Token 来买卖 NFT， NFTMarket 的函数有：

list() : 实现上架功能，NFT 持有者可以设定一个价格（需要多少个 Token 购买该 NFT）并上架 NFT 到 NFTMarket，上架之后，其他人才可以购买。

buyNFT() : 普通的购买 NFT 功能，用户转入所定价的 token 数量，获得对应的 NFT。

实现ERC20 扩展 Token 所要求的接收者方法 tokensReceived  ，在 tokensReceived 中实现NFT 购买功能。
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "../BaseERC721/MyERC721.sol";

contract NFTMarket {
  address public immutable token;
  MyERC721 public immutable nft;
  address public immutable _owner;
  mapping(uint256 => uint256) public nftPrices; // NFT id => 价格
  mapping(uint256 => address) public nftOwners; // NFT id => 拥有者地址

  // 每个地址的当前 nonce（签名使用计数）
  mapping(address => uint256) public nonces;
  mapping(bytes32 => bool) public cancelOrders;

  // EIP-712 域值常量，用于防止跨合约/链重放
  bytes32 public immutable DOMAIN_SEPARATOR;
  bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  // 签名类型哈希，用于离线签名结构
  bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address buyer,uint256 tokenId,uint256 value,uint256 nonce,uint256 deadline)");
  // 上架签名类型哈希
  bytes32 public constant LIST_PERMIT_TYPEHASH = keccak256("ListPermit(address seller,uint256 tokenId,uint256 price,uint256 deadline)");

  event NFTListed(address indexed seller, uint256 indexed nftId, uint256 price);
  event NFTSold(address indexed buyer, uint256 indexed nftId);
  event OrderCanceled(address indexed seller, uint256 indexed nftId);

  constructor(address _tokenAddress, address _nftAddress) {
    token = _tokenAddress;
    nft = MyERC721(_nftAddress);
    _owner = msg.sender;
    // 设置 EIP712 域分隔符（包含合约名称、版本、链ID、合约地址）
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        DOMAIN_TYPEHASH,
        keccak256(bytes("hoshino")), // 合约(name)哈希, 使用ERC721的名称
        keccak256(bytes("1")), // 版本号，可修改
        block.chainid,
        address(this)
      )
    );
  }

  fallback() external {
    revert("Fallback call");
  }

  // 上架NFT，设置价格
  function list(uint256 tokenId, uint256 price) public {
    require(nft.ownerOf(tokenId) == msg.sender, "You must own the NFT to list it");

    nftPrices[tokenId] = price;
    nftOwners[tokenId] = msg.sender;

    emit NFTListed(msg.sender, tokenId, price);
  }

  // 用户直接调用购买nft，需要在ERC20合约中给当前合约approve取钱额度
  function buyNFT(uint256 tokenId, uint256 amount) public {
    uint256 prices = nftPrices[tokenId];
    address oldOwner = nftOwners[tokenId];
    require(oldOwner != address(0), "nft not exist");
    require(msg.sender != oldOwner, "you are the owner of this nft");
    require(amount >= nftPrices[tokenId], "amount is not enough");

    IERC20(token).transferFrom(msg.sender, address(this), prices);
    transferNFT(msg.sender, tokenId);
    IERC20(token).transfer(oldOwner, prices);
    if (amount > prices) {
      IERC20(token).transfer(msg.sender, amount - prices);
    }
  }

  // 交易NFT
  function transferNFT(address addr, uint256 tokenId) internal {
    address oldOwner = nftOwners[tokenId];
    // 地址为0表示下架
    require(oldOwner != address(0), "nft not exist");
    require(oldOwner != addr, "you are the owner of this nft");

    // 代码顺序： 数据校验 -> 数据更新 -> 数据处理
    // 在开始处理的时候就清除上架信息，防止重入攻击
    nftPrices[tokenId] = 0;
    nftOwners[tokenId] = address(0);

    nft.safeTransferFrom(oldOwner, addr, tokenId);

    emit NFTSold(msg.sender, tokenId);
  }

  function tokensReceived(address _addr, uint256 _amount, bytes calldata _data) public returns (bool) {
    require(msg.sender == address(token), "Invalid sender address");
    uint256 tokenId = abi.decode(_data, (uint256));
    require(tokenId > 0, "Invalid Token ID");
    uint256 _value = nftPrices[tokenId];
    address _to = nftOwners[tokenId];
    require(_amount >= _value, "amount is not enough");

    transferNFT(_addr, tokenId);
    IERC20(token).transfer(_to, _value);
    if (_amount > _value) {
      IERC20(token).transfer(_addr, _amount - _value);
    }
    return true;
  }

  struct PermitData {
    address buyer;
    uint256 tokenId;
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
  }

  struct TokenPermitData {
    address owner;
    address spender;
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
  }

  struct ListPermitData {
    address seller;
    uint256 tokenId;
    uint256 price;
    uint256 deadline;
  }

  struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  struct PermitBuyWithOwnerSignatureParams {
    PermitData permitData;
    TokenPermitData tokenPermitData;
    ListPermitData listPermitData;
    Signature[] signature;
  }

  // 通过EIP712签名购买 NFT
  function permitBuy(PermitData calldata permitData, TokenPermitData calldata tokenPermitData, Signature[] calldata signature) public {
    require(permitData.deadline >= block.timestamp, "permitBuy: Permit expired");
    require(permitData.nonce == nonces[permitData.buyer], "permitBuy: Invalid nonce");
    Signature memory buySig = signature[0];
    bytes32 hashStruct = keccak256(
      abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(PERMIT_TYPEHASH, permitData.buyer, permitData.tokenId, permitData.amount, _useNonce(permitData.buyer), permitData.deadline))
      )
    );
    address signer = ecrecover(hashStruct, buySig.v, buySig.r, buySig.s);
    require(signer == _owner, "permitBuy: Invalid signature"); // 签名地址必须是合约部署者
    address oldOwner = nftOwners[permitData.tokenId];
    transferNFT(permitData.buyer, permitData.tokenId);
    Signature memory permitSig = signature[1];
    IERC20Permit(token).permit(tokenPermitData.owner, tokenPermitData.spender, tokenPermitData.amount, tokenPermitData.deadline, permitSig.v, permitSig.r, permitSig.s);
    IERC20(token).transferFrom(tokenPermitData.owner, oldOwner, tokenPermitData.amount);
  }

  // 通过EIP712签名购买 NFT,同时需要验证 NFT 拥有者的签名
  function permitBuyWithOwnerSignature(PermitBuyWithOwnerSignatureParams calldata params, bool useToken) public payable {
    require(params.listPermitData.deadline >= block.timestamp, "permitBuyWithOwnerSignature: Permit expired");
    require(params.permitData.deadline >= block.timestamp, "permitBuy: Permit expired");
    require(params.permitData.nonce == nonces[params.permitData.buyer], "permitBuy: Invalid nonce");
    // 上架签名生成的订单ID
    bytes32 orderid =
      keccak256(abi.encode(LIST_PERMIT_TYPEHASH, params.listPermitData.seller, params.listPermitData.tokenId, params.listPermitData.price, params.listPermitData.deadline));
    require(!cancelOrders[orderid], "permitBuyWithOwnerSignature: Order canceled");
    Signature memory listSig = params.signature[0];
    bytes32 hashStruct = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, orderid));
    address signer = ecrecover(hashStruct, listSig.v, listSig.r, listSig.s);
    address nftOwner = nft.ownerOf(params.listPermitData.tokenId);
    require(signer == nftOwner, "permitBuyWithOwnerSignature: Invalid list signature"); // 签名地址必须是NFT拥有者

    Signature memory buySig = params.signature[1];
    hashStruct = keccak256(
      abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,
        keccak256(
          abi.encode(PERMIT_TYPEHASH, params.permitData.buyer, params.permitData.tokenId, params.permitData.amount, _useNonce(params.permitData.buyer), params.permitData.deadline)
        )
      )
    );
    signer = ecrecover(hashStruct, buySig.v, buySig.r, buySig.s);
    require(signer == _owner, "permitBuyWithOwnerSignature: Invalid permit signature"); // 签名地址必须是合约部署者

    // 白名单用户携带上架者签名购买
    nft.safeTransferFrom(nftOwner, params.permitData.buyer, params.permitData.tokenId);
    emit NFTSold(msg.sender, params.permitData.tokenId);

    if (useToken) {
      // 使用token购买
      Signature memory permitSig = params.signature[2];
      IERC20Permit(token).permit(
        params.tokenPermitData.owner, params.tokenPermitData.spender, params.tokenPermitData.amount, params.tokenPermitData.deadline, permitSig.v, permitSig.r, permitSig.s
      );
      IERC20(token).transferFrom(params.tokenPermitData.owner, nftOwner, params.tokenPermitData.amount);
    } else {
      // 使用ETH购买
      require(msg.value >= params.permitData.amount, "permitBuyWithOwnerSignature: Insufficient ETH");
      payable(params.listPermitData.seller).transfer(params.listPermitData.price);
    }
  }

  // 取消订单，验签
  function cancelOrder(ListPermitData calldata listPermitData) public {
    // 验证签名 
    require(listPermitData.deadline >= block.timestamp, "cancelOrder: Permit expired");
    
    // 上架签名生成的订单ID
    bytes32 orderid = keccak256(abi.encode(LIST_PERMIT_TYPEHASH, listPermitData.seller, listPermitData.tokenId, listPermitData.price, listPermitData.deadline));
    require(!cancelOrders[orderid], "cancelOrder: Order already canceled");
    cancelOrders[orderid] = true;
    emit OrderCanceled(listPermitData.seller, listPermitData.tokenId);
  }

  function getNonce(uint256 tokenId) public view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(tokenId, msg.sender)));
  }

  function getPermitNonce(address owner) public view returns (uint256) {
    return nonces[owner];
  }

  function getNFTPrice(uint256 tokenId) public view returns (uint256) {
    return nftPrices[tokenId];
  }

  function _useNonce(address owner) internal virtual returns (uint256) {
    unchecked {
      return nonces[owner]++;
    }
  }

  function getNFTOwner(uint256 tokenId) public view returns (address) {
    return nftOwners[tokenId];
  }
}
