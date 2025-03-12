// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyWallet { 
    string public name;
    mapping (address => bool) private approved;
    address public owner;

    // 使用内联汇编检查授权的修饰符
    modifier auth {
        address _owner;
        assembly {
            _owner := sload(owner.slot)
        }
        require(msg.sender == _owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        // 使用汇编设置初始 owner
        assembly {
            sstore(owner.slot, caller()) // 使用 caller() 获取构造函数调用者的地址
        }
    } 

    function getOwnerAssembly() public view returns (address _owner) {
        assembly {
            _owner := sload(owner.slot)
        }
    }

    function transferOwernship(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");
        
        // 使用汇编获取当前 owner 并比较
        address currentOwner;
        assembly {
            currentOwner := sload(owner.slot)
        }
        require(currentOwner != _addr, "New owner is the same as the old owner");

        // 使用汇编设置新 owner
        assembly {
            sstore(owner.slot, _addr)
        }
    }
}