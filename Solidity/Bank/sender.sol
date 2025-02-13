// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//0xF221EEBE2990d66B591984b959E1839bEc54986B
contract sender {
    function send(address dest) external payable {
        require(msg.value > 0, unicode"转账金额必须大于0");
        (bool success, ) = dest.call{value: msg.value}("");
        require(success, unicode"发送失败");
    }
}
