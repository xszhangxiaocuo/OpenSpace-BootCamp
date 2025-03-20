// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EsRNT is ERC20, ERC20Permit, Ownable {
    using SafeERC20 for ERC20;
    address constant public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD; // 代币销毁地址
    uint256 public constant LOCK_PERIOD = 30 days; // esRNT 锁定 30 天
    ERC20 public RNT;       // RNT 代币地址
    // 用户 esRNT 锁定信息
    struct LockedEsRNT {
        uint256 amount;         // 锁定的 esRNT 数量
        uint256 unlockTime;     // 完全解锁时间
        bool isConvert;         // 是否已经转换为RNT
    }

    mapping(address => LockedEsRNT[]) public lockedRewards;

  event EsRNTConverted(address indexed user, uint256 esRNTAmount, uint256 rntAmount, uint256 burnedAmount);


  constructor(string memory _name, string memory _symbol,address _rnt) ERC20(_name, _symbol) ERC20Permit(_name) Ownable(msg.sender) {
        RNT = ERC20(_rnt);
  }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount); // 给质押用户发放奖励
        RNT.safeTransferFrom(msg.sender, address(this), _amount); // 从质押池转入奖励
        lockedRewards[_to].push(LockedEsRNT(_amount, block.timestamp + 30 days,false)); // 锁定 30 天
    }

    // 线性解锁 esRNT，返回需要销毁的 esRNT 数量
    function convertEsRNT(address to,uint256 id) public returns (uint256) {
        LockedEsRNT storage locked = lockedRewards[to][id];
        uint256 currentTime = block.timestamp;
        uint256 amount = locked.amount;
        require(amount > 0, "esRNT: no locked amount");
        require(locked.isConvert == false, "esRNT: already converted");
        locked.isConvert = true;

        if (currentTime < locked.unlockTime) { // 未到解锁时间，按线性解锁
            uint256 timeLeft = locked.unlockTime - currentTime;
            uint256 unlockedAmount = (amount * timeLeft) / LOCK_PERIOD; // 未解锁的部分
            RNT.safeTransfer(to, amount-unlockedAmount);
            RNT.safeTransfer(BURN_ADDRESS, unlockedAmount); // 销毁未解锁部分
            emit EsRNTConverted(to, amount, amount-unlockedAmount, unlockedAmount);
        } else { // 已到解锁时间，全部解锁
            RNT.safeTransfer(to, amount);
            emit EsRNTConverted(to, amount, amount, 0);
        }
        return amount;
    }

    function getLockedRewards(address _user) public view returns (LockedEsRNT[] memory) {
        return lockedRewards[_user];
    }
}
