// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/uniswap/IUniswapV2Factory.sol";
import "./interfaces/uniswap/IUniswapV2Pair.sol";
import "./interfaces/uniswap/IPangolinRouter.sol";
import './utils/SafeMath.sol';
import "./utils/PreciseUnitMath.sol";

contract SwapHelper {

    address internal constant VETH = address(1);
    bytes32 internal constant ROUTER_SLOT = 0x611dd9ef60700ba400f88e3ab2d74d522fb1b88c7bead11dc5f75b81cdb17086;
    using SafeMath for uint256;
    using PreciseUnitMath for uint256;
    /**
     * @dev swap exact tokens for AVAX
     *
     * @param tokenA tokenA address
     * @param amountA amount of tokenA
     *
     * @return pair reserveIn and reserveOut
     */
    function swapERC20ToETH(address tokenA, uint256 amountA,uint256 amountOutMin) external payable returns (uint256[] memory){
        require(tokenA != address(0), "invalid token A");

        address router = _router();
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = IPangolinRouter(router).WAVAX();
        require(IERC20(tokenA).approve(router, amountA), "failed to approve");
    
        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts;
        amounts = IPangolinRouter(router).swapExactTokensForAVAX(amountA, amountOutMin, path, payable(address(this)), deadline);
        return amounts;
    }

    /**
     * @dev swap exact AVAX for tokens
     *
     * @param tokenB tokenB address
     * @param amountA amount of tokenA
     *
     * @return pair reserveIn and reserveOut
     */
    function swapETHToERC20(address tokenB, uint256 amountA,uint256 amountOutMin) external payable returns (uint256[] memory){
        require(tokenB != address(0), "invalid token B");

        address router = _router();
        address[] memory path = new address[](2);
        path[0] = IPangolinRouter(router).WAVAX();
        path[1] = tokenB;

        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts = IPangolinRouter(router).swapExactAVAXForTokens{value:amountA}(amountOutMin, path, address(this), deadline);
        return amounts;
    }

    /**
     * @dev swap exact tokens for tokens
     *
     * @param tokenA tokenA address
     * @param amountA amount of tokenA
     * @param tokenB tokenB address
     *
     * @return pair reserveIn and reserveOut
     */
    function swapERC20ToERC20(address tokenA, address tokenB, uint256 amountA,uint256 amountOutMin) external payable returns (uint256[] memory){
        require(tokenA != address(0), "invalid token A");
        require(tokenB != address(0), "invalid token B");

        address router = _router();
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        require(IERC20(tokenA).approve(router, amountA), "failed to approve");

        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts = IPangolinRouter(router).swapExactTokensForTokens(amountA, amountOutMin, path, address(this), deadline);
        return amounts;
    }

    /**
     * @dev get amountOut for trading
     *
     * @param tokenA tokenA address
     * @param tokenB tokenB address
     * @param amountIn amount of tokenA
     *
     * @return amountOut
     */
    function getAmountOut(address tokenA, address tokenB,uint256 amountIn) public view returns(uint256 amountOut){
        IPangolinRouter UniswapV2Router = IPangolinRouter(_router());
        IUniswapV2Factory UniswapV2Factory = IUniswapV2Factory(UniswapV2Router.factory());
        address factoryAddress = UniswapV2Factory.getPair(tokenA, tokenB);
        require(factoryAddress != address(0), "token pair not found");

        IUniswapV2Pair UniswapV2Pair = IUniswapV2Pair(factoryAddress);
        (uint Res0, uint Res1,) = UniswapV2Pair.getReserves();
        if (tokenA < tokenB) {
            amountOut = UniswapV2Router.getAmountOut(amountIn, Res0, Res1);
        } else {
            amountOut = UniswapV2Router.getAmountOut(amountIn, Res1, Res0);
        }
        require(amountOut != 0, "failed to get PairPrice");
    }

    /**
     * @dev get router
     *
     * @return impl address
     */
    function _router() internal view returns(address impl) {
        bytes32 slot = ROUTER_SLOT;
        assembly {
          impl := sload(slot)
        }
    }

    /**
     * @dev get execute price
     * @param _buyAsset  the token address want to buy
     * @param _sellAsset  the token address want to sell
     * @param _tradeSize  sell amount
     * @param _isBuyingCollateral  is or not buy collateral
     *
     * @return execute price
     */
    function getExecutionPrice(
        address _buyAsset,
        address _sellAsset,
        uint256 _tradeSize,
        bool _isBuyingCollateral
    )
        public
        view
        returns (uint256)
    {
        IPangolinRouter router = IPangolinRouter(_router());
        address[] memory path = new address[](2);
        path[0] = _sellAsset;
        path[1] = _buyAsset;

        uint256[] memory flows = _isBuyingCollateral ? router.getAmountsIn(_tradeSize, path) : router.getAmountsOut(_tradeSize, path);

        uint256 buyDecimals = uint256(10)**IERC20(_buyAsset).decimals();
        uint256 sellDecimals = uint256(10)**IERC20(_sellAsset).decimals();
        uint256  price = flows[1].preciseDiv(buyDecimals).preciseDiv(flows[0].preciseDiv(sellDecimals));
        return price;
    }

    /**
     * @dev get price tokenA to tokenB according the price of tokenA to AVAX and the price of token B to AVAX
     * @param tokenA token A address
     * @param tokenB token B address
     */
    function getPairPrice(address tokenA, address tokenB) external payable returns(uint256 price){
        IPangolinRouter router = IPangolinRouter(_router());
         if(tokenA == VETH){
            tokenA =  router.WAVAX();
         }
         if(tokenB == VETH){
             tokenB = router.WAVAX();
         }
        price = getTokenA2TokenBRate(tokenA,tokenB);
    }


    /**
     * @dev return a price tokenA to tokenB transform by origin token (avax)
     * @param tokenA tokenA address
     * @param tokenB tokenB address
     * @return price
     */
     function getTokenA2TokenBRate(address tokenA, address tokenB) internal view returns(uint256 price){
        IPangolinRouter router = IPangolinRouter(_router());
        address wavax = router.WAVAX();
        uint256 priceB = getTokenA2TokenBPrice(tokenB,wavax);
        if(priceB > 0){
            price = getTokenA2TokenBPrice(tokenA,wavax).mul(1e18).div(priceB);
        }
        require(price !=  0,"price can't be 0");
    }

    /**
     * @dev return a price tokenA to tokenB
     * @param tokenA tokenA address
     * @param tokenB tokenB address
     * @return price (price tokenB per tokenA)
     */
    function getTokenA2TokenBPrice(address tokenA, address tokenB) public view returns(uint256 price){
        if(tokenA == tokenB){
            price = 1e18;
        }else{
            (uint256 Res0, uint256 Res1) = getPairReserves(tokenA, tokenB);
            price = calcPrices(tokenA, tokenB, Res0, Res1);
        }
    }


    /**
     * @dev return the reserves of tokenA and tokenB on dex
     * @param tokenA tokenA address
     * @param tokenB tokenB address
     * @return Res0  the reserves of toeken address is smaller one
     *         Res1  the reserves of toeken address is bigger one
     */
    function getPairReserves(address tokenA, address tokenB) internal view returns(uint256 Res0, uint256 Res1){
        IPangolinRouter router = IPangolinRouter(_router());
        IUniswapV2Factory UniswapV2Factory = IUniswapV2Factory(router.factory());
        address pairAddress = UniswapV2Factory.getPair(tokenA, tokenB);
        (Res0, Res1,) = IUniswapV2Pair(pairAddress).getReserves();
    }

    /**
     * @dev according to the reserve of tokenA and tokenB to calculate the price tokenA to tokenB
     * @param tokenA tokenA address
     * @param tokenB tokenB address
     * @return price (mantissa:1e18)
     */
    function calcPrices(address tokenA, address tokenB, uint256 Res0, uint256 Res1) internal view returns (uint256 price){
        IERC20 erctokenA = IERC20(tokenA);
        IERC20 erctokenB = IERC20(tokenB);
        if(tokenA < tokenB){
            price = Res1.mul(1e18).mul(10**(erctokenA.decimals())).div(Res0).div(10**(erctokenB.decimals()));
        }else{
            price = Res0.mul(1e18).mul(10**(erctokenA.decimals())).div(Res1).div(10**(erctokenB.decimals()));
        }
    }
}
