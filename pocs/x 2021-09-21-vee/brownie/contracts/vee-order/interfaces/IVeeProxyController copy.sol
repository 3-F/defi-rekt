// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the IVeeProxyController
 */
interface IVeeProxyController {  

    /*** Operation Events ***/
    /**
     * @notice Event emitted when the order are created.
     */
	event OnOrderCreated(bytes32 indexed orderId, address indexed orderOwner, address indexed tokenA, address cTokenA, address tokenB,uint amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay, uint256 maxSlippage);

     /*** Operation Events ***/
    /**
     * @notice Event emitted when the order are created.
     * typeCode 0:create 1:execute  2:cancel
     */
	event OnOrderPairPrice(bytes32 indexed orderId, uint8 indexed typeCode, uint256 tokenAToBasePrice,uint256 tokenBToBasePrice);

    /**
     * @notice Event emitted when the order are canceled.
     */
    event OnOrderCanceled(bytes32 indexed orderId, uint256 amount);

    /**
     * @notice Event emitted when the order are Executed.
     */
	event OnOrderExecuted(bytes32 indexed orderId, uint256 amount);    

    /**
     * @notice Event emitted when the token pair are exchanged.    
     */
	event OnTokenSwapped(bytes32 indexed orderId, address indexed orderOwner, address tokenA, address tokenB, uint256 amountA, uint256 amountB);

     /**
     * @notice Event emitted when repay borrow. 
     */
    event OnRepayBorrow(address borrower, address borrowToken, uint256 borrowAmount);

    /**
     * @notice Event emitted when Router is changed
     */
    event NewRouter(address oldRouter, address newRouter);


    /*** External functions ***/
    /**
     * @notice Sender create a stop-limit order with the below conditions from ERC20 TO ERC20.
     */
    function createOrderERC20ToERC20(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage) external returns (bytes32);

    /**
     * @notice Sender create a stop-limit order with the below conditions from ERC20 TO ETH.
     */
    function createOrderERC20ToETH(address orderOwner, address ctokenA, address tokenA, uint256 amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage) external returns (bytes32);

    /**
     * @notice Sender create a stop-limit order with the below conditions from ETH TO ERC20.
     */
    function createOrderETHToERC20(address orderOwner, address cETH,  address tokenB, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage) external payable returns (bytes32);

     /**
     * @notice check if the stop-limit order is expired or should be executed if the price reaches the stop/limit pair price.
     */
    function checkOrder(bytes32 orderId) external view returns (uint8);

    /**
     * @notice execute order if the stop-limit order is expired or should be executed if the price reaches the stop/limit value.
     */
    function executeOrder(bytes32 orderId) external returns (bool);

    /**
     * @notice cancel a valid order.
     */
    function cancelOrder(bytes32 orderId) external returns(bool);

    /**
     * @notice get details of a valid order.
     */
    function getOrderDetail(bytes32 orderId) external view returns(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage);
 }
