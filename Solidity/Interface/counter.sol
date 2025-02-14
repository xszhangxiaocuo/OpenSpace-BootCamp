// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICounter {
    function increment() external;
}

contract Counter is ICounter {
    uint256 public counterValue;
    function increment() external  {
        ++counterValue;
    }
}

contract mycontract {
    ICounter internal ic;
    Counter internal c=new Counter();
    function myincrement() external {
        ic = ICounter(c);
    }
}