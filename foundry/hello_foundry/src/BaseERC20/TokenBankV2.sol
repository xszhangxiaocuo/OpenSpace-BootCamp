// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenBank.sol";

contract TokenBankV2 is TokenBank {
    constructor (address _token) TokenBank(_token) {}

    // 接收转账的回调函数
    function tokensReceived(
        address _addr,
        uint256 _amount,
        bytes memory _data
    ) public returns (bool) {
        // 校验调用者是否是指定的ERC20合约
        require(msg.sender==tokens, "Invalid sender address");
        balances[_addr] += _amount;
        return true;
    }
}