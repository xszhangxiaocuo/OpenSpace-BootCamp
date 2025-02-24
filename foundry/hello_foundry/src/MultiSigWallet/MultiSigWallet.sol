// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * 实现⼀个简单的多签合约钱包，合约包含的功能：
 *
 * 创建多签钱包时，确定所有的多签持有⼈和签名门槛
 * 多签持有⼈可提交提案
 * 其他多签⼈确认提案（使⽤交易的⽅式确认即可）
 * 达到多签⻔槛、任何⼈都可以执⾏交易
 */
contract MultiSigWallet {
  // 多签持有⼈
  address[] public owners;
  // 签名门槛
  uint256 public required;

  // 地址 => 是否是多签持有⼈
  mapping(address => bool) public isOwner;
  // 提案编号 => 提案
  mapping(uint256 => Proposal) public proposals;
  // 提案数量
  uint256 public proposalCount;

  // 提案
  struct Proposal {
    address to;
    uint256 amount;
    bytes data;
    bool executed; // 标记提案是否已执⾏
    uint256 confirmCount; // 已确认的签名数量
    mapping(address => bool) isConfirmed; // 地址 => 是否已确认
  }

  event ProposalCreated(uint256 indexed proposalId, address to, uint256 amount, bytes data);
  event ProposalConfirmed(uint256 indexed proposalId, address indexed owner);
  event ProposalExecuted(uint256 indexed proposalId);
  event Deposit(address indexed sender, uint256 amount);
  event Transfer(address indexed to, uint256 amount);

  modifier onlyOwner() {
    require(isOwner[msg.sender], "only owner");
    _;
  }

  modifier notConfirmed(uint256 _proposalId) {
    require(!proposals[_proposalId].isConfirmed[msg.sender], "you already confirmed");
    _;
  }

  modifier notExecuted(uint256 _proposalId) {
    require(!proposals[_proposalId].executed, "proposal already executed");
    _;
  }

  receive() external payable {
    emit Deposit(msg.sender, msg.value);
  }

  constructor(address[] memory _owners, uint256 _required) {
    require(_owners.length > 0, "owners required");
    require(_required > 0 && _required <= _owners.length, "required should be greater than 0 and less than or equal to owners.length");
    for (uint256 i = 0; i < _owners.length; i++) {
      require(_owners[i] != address(0), "owner should not be zero address");
      isOwner[_owners[i]] = true;
    }
    owners = _owners;
    required = _required;
  }

  // 提交提案
  function submitProposal(address _to, uint256 amount, bytes calldata _data) public onlyOwner returns (uint256) {
    proposalCount++;
    Proposal storage proposal = proposals[proposalCount];
    proposal.to = _to;
    proposal.amount = amount;
    proposal.data = _data;
    proposal.executed = false;
    proposal.confirmCount = 0;
    emit ProposalCreated(proposalCount, _to, amount, _data);
    confirmProposal(proposalCount);
    return proposalCount;
  }

  // 确认提案
  function confirmProposal(uint256 _proposalId) public onlyOwner notConfirmed(_proposalId) notExecuted(_proposalId) {
    Proposal storage proposal = proposals[_proposalId];
    proposal.isConfirmed[msg.sender] = true;
    proposal.confirmCount++;
    emit ProposalConfirmed(_proposalId, msg.sender);
    if (proposal.confirmCount >= required) {
      executeProposal(_proposalId);
    }
  }

  // 执行提案
  function executeProposal(uint256 _proposalId) public onlyOwner notExecuted(_proposalId) {
    Proposal storage proposal = proposals[_proposalId];
    require(proposal.confirmCount >= required, "confirm count not enough");
    proposal.executed = true;
    (bool success,) = proposal.to.call{ value: proposal.amount }(proposal.data);
    require(success, "execute failed");
    emit ProposalExecuted(_proposalId);
    emit Transfer(proposal.to, proposal.amount);
  }

  function getIsConfirmed(uint256 _proposalId, address _owner) public view returns (bool) {
    return proposals[_proposalId].isConfirmed[_owner];
  }

  function getConfirmed(uint256 _proposalId) public view returns (uint256) {
    return proposals[_proposalId].confirmCount;
  }

  function getExecuted(uint256 _proposalId) public view returns (bool) {
    return proposals[_proposalId].executed;
  }
}
