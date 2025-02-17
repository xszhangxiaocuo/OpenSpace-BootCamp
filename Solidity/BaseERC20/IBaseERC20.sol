// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBaseERC20 {
    // 查询某个地址的余额
    function balanceOf(address _owner) external view returns (uint256);

    // 转账方法
    function transfer(address _to, uint256 _value) external returns (bool);

    // 代理转账方法
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);

    // 授权方法：允许某个地址花费 msg.sender 的代币
    function approve(address _spender, uint256 _value) external returns (bool);

    // 查询授权额度
    function allowance(address _owner, address _spender) external view returns (uint256);

    // 带回调的转账方法
    function transferWithCallback(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (bool);
}