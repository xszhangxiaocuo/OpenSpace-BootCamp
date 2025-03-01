// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "../utils/Counters.sol";

contract MyERC721 is ERC721URIStorage {
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;

  constructor() ERC721(unicode"hoshino", "ho") { }

  function mint(address student, string memory tokenURI) public returns (uint256) {
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();
    _mint(student, newItemId);
    _setTokenURI(newItemId, tokenURI);
    return newItemId;
  }
}
