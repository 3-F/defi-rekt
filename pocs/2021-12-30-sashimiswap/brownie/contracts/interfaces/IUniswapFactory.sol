// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.24;

interface IFactory {
    function getPair(address, address) external returns(address);
}