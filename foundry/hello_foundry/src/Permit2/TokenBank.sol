// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./IPermit2.sol";

contract TokenBank {
  address public tokens;
  IPermit2 public permit2;
  mapping(address => uint256) public balances;

  event Deposited(address indexed user, uint256 amount);
  event DepositedPermit2(address indexed user, IERC20 tokens, uint256 amounts);
  event Withdrawn(address indexed user, uint256 amount);

  constructor(address _token, address _permit2) {
    tokens = _token;
    permit2 = IPermit2(_permit2);
  }

  modifier enoughBalance(address _addr, uint256 _amount) {
    require(balances[_addr] >= _amount, "TokenBank: Insufficient balance in TokenBank");
    _;
  }

  function deposit(uint256 amount) public {
    (bool success,) = tokens.call(abi.encodeCall(IERC20(tokens).transferFrom, (msg.sender, address(this), amount)));
    require(success, "TokenBank: deposit failed");
    balances[msg.sender] += amount;
    emit Deposited(msg.sender, amount);
  }

  function withdraw(uint256 amount) public enoughBalance(msg.sender, amount) {
    (bool success,) = tokens.call(abi.encodeCall(IERC20(tokens).transfer, (msg.sender, amount)));
    require(success, "TokenBank: withdraw failed");
    balances[msg.sender] -= amount;

    emit Withdrawn(msg.sender, amount);
  }

  function permitDeposit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
    require(amount > 0, "Amount must be greater than 0");
    IERC20Permit(tokens).permit(owner, spender, amount, deadline, v, r, s);
    IERC20(tokens).transferFrom(owner, address(this), amount);
    balances[owner] += amount;
    emit Deposited(owner, amount);
  }

  function depositWithPermit2(IERC20 token, uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature) public {
    IPermit2.SignatureTransferDetails memory transferDetails;
    balances[msg.sender] += amount;

    transferDetails = IPermit2.SignatureTransferDetails({ to: address(this), requestedAmount: amount });
    permit2.permitTransferFrom(
      IPermit2.PermitTransferFrom({ permitted: IPermit2.TokenPermissions({ token: token, amount: amount }), nonce: nonce, deadline: deadline }),
      transferDetails,
      msg.sender,
      signature
    );

    emit DepositedPermit2(msg.sender, token, amount);
  }

  function _toTokenPermissionsArray(IERC20[] calldata token, uint256[] calldata amounts) private pure returns (IPermit2.TokenPermissions[] memory permissions) {
    permissions = new IPermit2.TokenPermissions[](token.length);
    for (uint256 i; i < permissions.length; ++i) {
      permissions[i] = IPermit2.TokenPermissions({ token: token[i], amount: amounts[i] });
    }
  }

  function getDepositBalance(address user) public view returns (uint256) {
    return balances[user];
  }
}
