// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IVeeProxyController {
    function deposit(address account, address token, uint256 amount, uint8 leverage) external payable;
}