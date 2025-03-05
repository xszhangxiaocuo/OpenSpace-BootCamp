// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTMarketSigutils {
  bytes32 internal DOMAIN_SEPARATOR;
  bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  constructor(address addr) {
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        DOMAIN_TYPEHASH,
        keccak256(bytes("hoshino")), // 合约(name)哈希, 使用ERC721的名称
        keccak256(bytes("1")), // 版本号，可修改
        block.chainid,
        addr
      )
    );
  }

  // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address buyer,uint256 tokenId,uint256 value,uint256 nonce,uint256 deadline)");
  bytes32 public constant LIST_PERMIT_TYPEHASH = keccak256("ListPermit(address seller,uint256 tokenId,uint256 price,uint256 deadline)");

  struct Permit {
    address buyer;
    uint256 tokenId;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }

  struct ListPermit {
    address seller;
    uint256 tokenId;
    uint256 price;
    uint256 deadline;
  }

  // computes the hash of a permit
  function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
    return keccak256(abi.encode(PERMIT_TYPEHASH, _permit.buyer, _permit.tokenId, _permit.value, _permit.nonce, _permit.deadline));
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
  }

  // computes the hash of a permit
  function getListStructHash(ListPermit memory _permit) internal pure returns (bytes32) {
    return keccak256(abi.encode(LIST_PERMIT_TYPEHASH, _permit.seller, _permit.tokenId, _permit.price, _permit.deadline));
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getListTypedDataHash(ListPermit memory _permit) public view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getListStructHash(_permit)));
  }
}
