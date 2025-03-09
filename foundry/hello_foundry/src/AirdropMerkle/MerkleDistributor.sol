//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * Ref: https://github.com/Uniswap/merkle-distributor
 */
contract MerkleDistributor {
  bytes32 public immutable merkleRoot;

  event Claimed(address account);

  constructor(bytes32 merkleRoot_) {
    merkleRoot = merkleRoot_;
  }

  function claim(address account, bytes32[] calldata merkleProof) public {
    // Verify the merkle proof.
    bytes32 node = keccak256(abi.encodePacked(account));

    require(MerkleProof.verify(merkleProof, merkleRoot, node), "MerkleDistributor: Invalid proof.");

    // do your logic accordingly here

    emit Claimed(account);
  }
}
