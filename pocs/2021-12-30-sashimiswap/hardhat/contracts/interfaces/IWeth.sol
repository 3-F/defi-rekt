// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.24;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint) external;
}
