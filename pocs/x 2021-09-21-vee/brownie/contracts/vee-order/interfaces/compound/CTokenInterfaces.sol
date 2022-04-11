// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ComptrollerInterface.sol";
import "./InterestRateModel.sol";
import "./EIP20NonStandardInterface.sol";

interface CTokenInterface {
    /**
     * @notice Indicator that this is a CToken contract (for inspection)
     */
    function isCToken() external returns (bool);
    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function accrueInterest() external returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);
    function accountLeverage(address borrower) external view returns (uint);
}

interface CErc20Interface {

    /*** User Interface ***/

    // function mint(uint mintAmount) external returns (uint);
    // function redeem(uint redeemTokens) external returns (uint);
    // function redeemUnderlying(uint redeemAmount) external returns (uint);
    // function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
    function underlying() external returns (address);
    function repayLeverageAndBorrow(address borrower, uint repayAmount, uint expectLeverageAmount, uint realLeverageAmount) external returns (uint,uint);
}
