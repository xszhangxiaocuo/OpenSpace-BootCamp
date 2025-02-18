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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor() {
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 100000000 * 10**decimals;
        balances[msg.sender] = totalSupply;
    }

    // 校验非0地址
    modifier noneZeroAdress(address _addr) {
        require(_addr != address(0), "ERC20: transfer to zero address");
        _;
    }

    // 校验余额
    modifier enoughBalance(address _addr, uint256 _value) {
        require(
            balances[_addr] >= _value,
            "ERC20: transfer amount exceeds balance"
        );
        _;
    }

    // 校验代取额度
    modifier enoughAllowances(
        address _from,
        address _to,
        uint256 _value
    ) {
        require(
            allowances[_from][_to] >= _value,
            "ERC20: transfer amount exceeds allowance"
        );
        _;
    }

    // 查询某个地址的余额
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    // 转账方法
    function transfer(address _to, uint256 _value)
        public
        noneZeroAdress(_to)
        enoughBalance(msg.sender, _value)
        returns (bool)
    {
        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // 代理转账方法
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        noneZeroAdress(_to)
        enoughBalance(_from, _value)
        enoughAllowances(_from, msg.sender, _value)
        returns (bool)
    {
        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    // 授权方法：允许某个地址花费 msg.sender 的代币
    function approve(address _spender, uint256 _value)
        public
        noneZeroAdress(_spender)
        returns (bool)
    {
        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // 查询授权额度
    function allowance(address _owner, address _spender)
        public
        view
        returns (uint256)
    {
        return allowances[_owner][_spender];
    }

    // 扩展 ERC20 合约 ，添加一个有 hook 功能的转账函数，如函数名为：transferWithCallback。
    // 在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。
    function transferWithCallback(
        address _to,
        uint256 _value,
        bytes calldata _data
    )
        public
        noneZeroAdress(_to)
        enoughBalance(msg.sender, _value)
        returns (bool)
    {
        require(msg.sender!=_to,"ERC20: can not transfer to yourself");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        // 调用目标地址的 tokensReceived() 方法
        if (_isContract(_to)) {
            (bool success, ) = _to.call(
                abi.encodeWithSignature(
                    "tokensReceived(address,uint256,bytes)",
                    msg.sender,
                    _value,
                    _data
                )
            );
            require(success, "ERC20: call tokensReceived failed!");
        }
        return true;
    }

    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
