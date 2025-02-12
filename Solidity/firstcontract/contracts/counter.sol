//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Counter {
    uint256 internal count = 0;

    constructor() {}

    function get() public view returns (uint256) {
        return count;
    }

    function add(uint256 x) public {
        count += x;
    }
}
