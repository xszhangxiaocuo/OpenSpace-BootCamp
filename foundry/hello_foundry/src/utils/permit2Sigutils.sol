// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPermit2 } from "../Permit2/IPermit2.sol";

contract permit2SigUtils {
  bytes32 internal DOMAIN_SEPARATOR;
  bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
  bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

  constructor(address addr) {
    DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("Permit2")), block.chainid, addr));
  }

  bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH =
    keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)");

  struct PermitTransferFrom {
    IPermit2.TokenPermissions permitted;
    address spender;
    uint256 nonce;
    uint256 deadline;
  }

  // computes the hash of a permit
  function getStructHash(PermitTransferFrom memory _permit) internal pure returns (bytes32) {
    // return keccak256(abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, keccak256(abi.encode(_permit.permitted.token, _permit.permitted.amount)), _permit.spender, _permit.nonce, _permit.deadline));
    return keccak256(abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, _permit.permitted)), _permit.spender, _permit.nonce, _permit.deadline));
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getTypedDataHash(PermitTransferFrom memory _permit) public view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
  }
}
