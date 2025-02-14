// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBank {
    function withdraw(uint256 amount) external;
    function getRank() external view returns (address[3] memory);
    function getBalance() external view returns (uint256);
    function getContractBalance() external view returns (uint256);
}