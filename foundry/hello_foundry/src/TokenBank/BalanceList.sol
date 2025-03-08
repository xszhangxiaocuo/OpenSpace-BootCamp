// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BalanceList {
  struct User {
    uint256 balance;
    address next;
    address prev;
  }

  mapping(address => uint256) public balances;
  mapping(address => User) _userList;
  uint256 public listSize;

  address constant GUARD = address(1);

  constructor() {
    _userList[GUARD] = User({ balance: 0, next: GUARD, prev: GUARD });
  }

  function addUser(address user, uint256 balance) public {
    require(!isUser(user));
    _userList[user] = User({ balance: balance, next: _userList[GUARD].next, prev: GUARD });
    _userList[GUARD].next = user;
    _userList[_userList[user].next].prev = user;
    updateRank(user);
    listSize++;
    if (listSize > 10) {
      removeStudent(_userList[GUARD].next);
    }
  }

  function removeStudent(address user) public {
    require(isUser(user));
    address prevUser = _userList[user].prev;
    _userList[prevUser].next = _userList[user].next;
    _userList[_userList[user].next].prev = prevUser;
    delete _userList[user];

    listSize--;
  }

  function isUser(address user) public view returns (bool) {
    return _userList[user].next != address(0);
  }

  function getUsers() public view returns (address[] memory) {
    address[] memory users = new address[](listSize);
    User memory current = _userList[GUARD];
    for (uint256 i = 0; current.next != GUARD; ++i) {
      users[i] = current.next;
      current = _userList[current.next];
    }
    return users;
  }

  // 链表从小到大排列，返回最小的存款
  function getMinBalance() public view returns (uint256) {
    return _userList[GUARD].next.balance;
  }

  function updateBalance(address user, uint256 newBalance) public {
    require(isUser(user));
    require(newBalance != _userList[user].balance);

    _userList[user].balance = newBalance;
    updateRank(user);
  }

  function updateRank(address user) public {
    require(isUser(user));
    address pos = findPosition(_userList[user].balance);
    if (pos == user) {
      return;
    }
    User memory currentUser = _userList[pos];
    User memory newUser = _userList[user];

    // 先将user从链表中删除
    _userList[newUser.prev].next = newUser.next;
    _userList[newUser.next].prev = newUser.prev;

    // 将user插入到pos之前
    newUser.next = pos;
    newUser.prev = currentUser.prev;

    currentUser.prev = user;
    _userList[newUser.prev].next = user;
  }

  function findPosition(uint256 balance) public view returns (address) {
    address currentAddress = _userList[GUARD].next;
    while (_userList[currentAddress].balance > balance || _userList[currentAddress].next == GUARD) {
      currentAddress = _userList[currentAddress].next;
    }
    return currentAddress;
  }
}
