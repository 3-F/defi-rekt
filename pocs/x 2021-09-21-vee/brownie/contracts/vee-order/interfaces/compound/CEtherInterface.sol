// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface CEtherInterface{
    function repayBorrowBehalf(address borrower) external payable;   
    function repayLeverageAndBorrow(address borrower, uint repayAmount, uint expectLeverageAmount, uint realLeverageAmount) external payable returns (uint,uint);
}