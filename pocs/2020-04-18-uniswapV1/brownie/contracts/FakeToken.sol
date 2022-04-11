pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FakeToken is ERC20("FakeToken", "FT") {
    constructor() public {
        _mint(msg.sender, 100000e18);
    }
}
