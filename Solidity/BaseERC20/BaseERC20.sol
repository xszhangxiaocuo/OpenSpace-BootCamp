// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
完善合约，实现以下功能：

设置 Token 名称（name）："BaseERC20"
设置 Token 符号（symbol）："BERC20"
设置 Token 小数位decimals：18
设置 Token 总量（totalSupply）:100,000,000
允许任何人查看任何地址的 Token 余额（balanceOf）
允许 Token 的所有者将他们的 Token 发送给任何人（transfer）；转帐超出余额时抛出异常(require),并显示错误消息 “ERC20: transfer amount exceeds balance”。
允许 Token 的所有者批准某个地址消费他们的一部分Token（approve）
允许任何人查看一个地址可以从其它账户中转账的代币数量（allowance）
*/

contract BaseERC20 {
    string public name; 
    string public symbol; 
    uint8 public decimals;
    uint256 public totalSupply; 

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 100000000 * 10**decimals;
        balances[msg.sender] = totalSupply;
    }

    // 查询某个地址的余额
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    // 转账方法
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance");
        require(_to != address(0), "ERC20: transfer to zero address");

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // 代理转账方法
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");
        require(allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance");
        require(_to != address(0), "ERC20: transfer to zero address");

        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    // 授权方法：允许某个地址花费 msg.sender 的代币
    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != address(0), "ERC20: approve to zero address");

        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // 查询授权额度
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }
}