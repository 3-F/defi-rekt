// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IPositionToken {
    function mintWithEther(address receiver, uint256 maxPriceAllowed) 
        external 
        payable 
        returns (uint256);
}