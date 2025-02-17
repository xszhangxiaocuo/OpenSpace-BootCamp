// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
编写一个简单的 NFTMarket 合约，使用自己发行的ERC20 扩展 Token 来买卖 NFT， NFTMarket 的函数有：

list() : 实现上架功能，NFT 持有者可以设定一个价格（需要多少个 Token 购买该 NFT）并上架 NFT 到 NFTMarket，上架之后，其他人才可以购买。

buyNFT() : 普通的购买 NFT 功能，用户转入所定价的 token 数量，获得对应的 NFT。

实现ERC20 扩展 Token 所要求的接收者方法 tokensReceived  ，在 tokensReceived 中实现NFT 购买功能。
*/

import "../BaseERC20/IBaseERC20.sol";
import "../BaseERC721/MyERC721.sol";

contract NFTMarket {
    IBaseERC20 public token;
    MyERC721 public nft;
    mapping(uint256 => uint256) public nftPrices;  // NFT id => 价格
    mapping(uint256 => address) public nftOwners;  // NFT id => 拥有者地址
    mapping(address => uint256) private balances;

    event NFTListed(address indexed seller, uint256 indexed nftId, uint256 price);
    event NFTSold(address indexed buyer, uint256 indexed nftId, uint256 price);

    constructor(address _tokenAddress, address _nftAddress) {
        token = IBaseERC20(_tokenAddress);
        nft = MyERC721(_nftAddress);
    }

     // 上架NFT，设置价格
    function list(uint256 nftId, uint256 price) public  {
        require(nft.ownerOf(nftId) == msg.sender, "You must own the NFT to list it");

        nftPrices[nftId] = price;
        nftOwners[nftId] = msg.sender;

        emit NFTListed(msg.sender, nftId, price);
    }

    // 购买NFT
    function buyNFT(uint256 tokenId, uint256 amount) public {
        // 地址为0表示下架
        require(nftOwners[tokenId]!=address(0),"nft no exist");
        require(balances[msg.sender]>=amount,"blance is not enough");

        address nftOwner = nftOwners[tokenId];

        nft.safeTransferFrom(nftOwner, msg.sender, tokenId);

        uint256 price = nftPrices[tokenId];
        balances[msg.sender] -= price;
        balances[nftOwner] += price;

        // 清除上架信息
        nftPrices[tokenId] = 0;
        nftOwners[tokenId] = address(0);

        emit NFTSold(msg.sender, tokenId, amount);
    }

    // 用户提取代币
    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }

    function balanceOf(address addr) public view returns (uint256) {
        return balances[addr];
    }

    function tokensReceived(
        address _addr,
        uint256 _amount,
        bytes calldata _data
    ) public returns (bool) {
        balances[_addr] += _amount;
         // 如果 _data 不为空，则尝试解码为 uint256（NFT 的 Token ID）
        if (_data.length > 0 && _data[0] != 0x00) {
            uint256 tokenId = abi.decode(_data, (uint256));
            
            require(tokenId > 0, "Invalid Token ID");
            buyNFT(tokenId,nftPrices[tokenId]);
        }

        return true;
    }
}