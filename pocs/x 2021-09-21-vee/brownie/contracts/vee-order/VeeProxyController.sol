// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./VeeSystemController.sol";
import "./interfaces/compound/CEtherInterface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./utils/SafeERC20.sol";
import "./interfaces/compound/CTokenInterfaces.sol";
import "./interfaces/uniswap/IUniswapV2Factory.sol";
import "./interfaces/uniswap/IUniswapV2Pair.sol";
import "./interfaces/uniswap/IPangolinRouter.sol";
import "./utils/PreciseUnitMath.sol";
import "./interfaces/IPriceOracle.sol";
/**
 * @title  Vee's proxy Contract
 * @notice Implementation of the {VeeProxyController} interface.
 * @author Vee.Finance
 */
contract VeeProxyController is VeeSystemController, Initializable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using PreciseUnitMath for uint256;
     /**
     * @dev swap router storage slot
     */
    bytes32 internal constant ROUTER_SLOT = 0x611dd9ef60700ba400f88e3ab2d74d522fb1b88c7bead11dc5f75b81cdb17086;

    /**
     * @dev state code for Check Order
     */
    enum StateCode {
            EXECUTE,
            EXPIRED,
            NOT_RUN
        }

    /**
     * @dev Order data
     */
    struct Order {
        address orderOwner;
        address ctokenA;
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
        uint256 stopHighPairPrice;
        uint256 stopLowPairPrice;
        uint256 expiryDate;
        uint8   leverage;
    }


    /**
     * @param orderOwner  The address of order owner
     * @param ctokenA     The address of ctoken A
     * @param ctokenB      The address of ctoken B
     * @param amountA     The token A amount
     * @param stopHighPairPrice  limit token pair price
     * @param stopLowPairPrice   stop token pair price
     * @param expiryDate   expiry date
     * @param leverage    levarage
     */
    struct CreateParams {
       address ctokenA;
       address ctokenB;
       uint256 amountA;
       uint256 stopHighPairPrice;
       uint256 stopLowPairPrice;
       uint256 expiryDate;
       uint8 leverage;
    }

    /**
     * @dev container for saving orderid dand order infornmation
     */
    mapping (bytes32 => Order) private orders;

    /**
     * @dev AssetBook data
     */
    struct AssetBook{
        mapping(address => uint256) accountBalance;
        mapping(address => uint256) accountLeverageBalance;
        mapping(address => bool) assetMember;
    }

    mapping (address => uint256) public platformFees;


    /**
     * @dev mapping for asset address to AssetBook
     */
    mapping(address => AssetBook) private _assetBooks;

    /**
     * @dev mapping for account address to deposited asset addresses
     */
    mapping(address => address[]) public accountAssets;

    /**
     * @dev tokenB whitelist
     */
    mapping(address => bool) whiteList;

    address private _cether;

    /**
     * @dev address of SwapHelper
     */
    address public swapHelper;

    address public oracle;

    /**
     * @dev increasing number for generating random.
     */
    uint256 private nonce;

    /**
     * @dev The fixed amount 0f avax
     */
    uint256 public originFee;

    /**
     * @dev The fixed amount 0f avax
     */
    uint256 public serviceFee;

    /**
     * @dev The max support leverage
     */
    uint8 public maxLeverage;

    /**
     * @dev margin rate (default: 1e18 - 1e17)
     */
    uint256 public marginRate;

    /**
     * @dev the order max survival cycle 
     */
    uint256 public maxExpire;

    /**
     * @dev the max order size limit
     * mantissa: 18
     */
    uint256 public sizeLimit;


    /*** Operation Events ***/
    /**
     * @notice Event emitted when the order are created.
     */
	event OnOrderCreated(bytes32 indexed orderId, address indexed orderOwner, address indexed tokenA, address cTokenA, address tokenB,uint amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, uint8 leverage, uint256 tokenAToBasePrice, uint256 tokenBToBasePrice);

     /*** Operation Events ***/

    /**
     * @notice Event emitted when the order are canceled.
     */
    event OnOrderCanceled(bytes32 indexed orderId, uint256 amountIn, uint256 amountOut, uint256 stopLowPrice, uint256 stopHighPrice, uint256 executeionPrice, uint256 tokenAToBasePrice,uint256 tokenBToBasePrice);

    /**
     * @notice Event emitted when the order are Executed.
     */
	event OnOrderExecuted(bytes32 indexed orderId, uint256 amountIn, uint256 amountOut, uint256 stopLowPrice, uint256 stopHighPrice, uint256 executeionPrice, uint256 tokenAToBasePrice,uint256 tokenBToBasePrice);

    /**
     * @notice Event emitted when the token pair are exchanged.
     */
	event OnTokenSwapped(bytes32 indexed orderId, address indexed orderOwner, address tokenA, address tokenB, uint256 amountA, uint256 amountB);

    /**
     * @notice Event emitted when Router is changed
     */
    event NewRouter(address oldRouter, address newRouter);
    /**
     * @notice Event emitted when user deposit assets
     */
    event Deposit(address account, address token, uint256 totalPrincipalAmount, uint256 exceptLeverageAmount,uint256 leverageAmount);
    /**
     * @notice Event emitted when SwapHelper is changed
     */
    event NewSwapHelper(address oldSwapHelper, address newSwapHelper);
    /**
     * @notice Event emitted when serviceFee is changed
     */
    event NewServiceFee(uint256 oldServiceFee, uint256 newServiceFee);

    /**
     * @notice Event emitted when originFee is changed
     */
    event NewOriginFee(uint256 oldOriginFee, uint256 newOriginFee);

     /**
     * @notice Event emitted when originFee is changed
     */
    event NewMaxLeverage(uint8 oldMaxLeverage, uint8 newMaxLeverage);


    /**
     * @notice Event emitted when oracle is changed
     */
    event NewOracle(address oldOracle, address newOracle);

    /**
     * @notice Event emitted when size limit is changed
     */
    event NewSizeLimit(uint256 oldLimit, uint256 newLimit);

    /**
     * @notice Event emitted when whitelist is changed
     */
    event WhiteListChanged(uint8 oprationCode, address token);

     /**
     * @notice Event emitted when profit > 0
     */
    event TransferProfit(address indexed tokenA, address indexed tokenB, uint256 profit);


    event OnWithdrawPlatformFee(address indexed token, uint256 amount);

    /**
     * @dev called for plain Ether transfers
     */
    receive() payable external{}

    /**
     * @dev initialize for initializing UNISWAP router and CETH
     */
    function initialize(address router_, address cether, address[] memory _whiteList,address _oracle,address _admin) public initializer {
        _setRoleAdmin(PROXY_ADMIN_ROLE, PROXY_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE,    PROXY_ADMIN_ROLE);
        _setRoleAdmin(VEETOKEN_ROLE,    PROXY_ADMIN_ROLE);

        // deployer + self administration
        _setupRole(PROXY_ADMIN_ROLE, _admin);
        _setupRole(PROXY_ADMIN_ROLE, address(this));

        _cether = cether;
        _setRouter(router_);
        _notEntered = true;
        serviceFee = 5e15;
        originFee = 5e16;
        marginRate = 9e17;  // 1e18 - 1e17
        maxLeverage = 3;
        maxExpire = 30 days;
        sizeLimit = 5000e18;
        _add2WhiteList(_whiteList);
        oracle = _oracle;
    }

    /*** External Functions ***/
     /**
     * @dev Sender create a stop-limit order with the below conditions from ERC20 TO ERC20.
     *
     * @return orderId
     */
    function createOrderERC20ToERC20(address orderOwner,CreateParams memory createParams) external veeLock(uint8(VeeLockState.LOCK_CREATE)) payable returns (bytes32 orderId){
        address tokenA = CErc20Interface(createParams.ctokenA).underlying();
        address tokenB = CErc20Interface(createParams.ctokenB).underlying();
        commonCheck(orderOwner, createParams.stopHighPairPrice, createParams.stopLowPairPrice, createParams.amountA, createParams.expiryDate, createParams.leverage, createParams.ctokenA, tokenA,tokenB);
        uint256[] memory amounts = swapERC20ToERC20(tokenA, tokenB, calcSwapAmount(createParams.amountA, createParams.leverage),getAmountOutMin(createParams));
        orderId = onOrderCreate(orderOwner,createParams,amounts,tokenA,tokenB);
    }

    /**
     * @dev Sender create a stop-limit order with the below conditions from ERC20 TO ETH.
     *
     * @return orderId
     */
    function createOrderERC20ToETH(address orderOwner,CreateParams memory createParams) external veeLock(uint8(VeeLockState.LOCK_CREATE)) payable returns (bytes32 orderId){
        address tokenA = CErc20Interface(createParams.ctokenA).underlying();
        commonCheck(orderOwner, createParams.stopHighPairPrice, createParams.stopLowPairPrice, createParams.amountA, createParams.expiryDate, createParams.leverage, createParams.ctokenA, tokenA,VETH);
        uint256[] memory amounts = swapERC20ToETH(tokenA, calcSwapAmount(createParams.amountA, createParams.leverage),getAmountOutMin(createParams));
        orderId = onOrderCreate(orderOwner,createParams,amounts,tokenA,VETH);
    }

    /**
     * @dev Sender create a stop-limit order with the below conditions from ETH TO ERC20.
     *
     * @return orderId
     */
    function createOrderETHToERC20(address orderOwner,CreateParams memory createParams) external veeLock(uint8(VeeLockState.LOCK_CREATE)) payable returns (bytes32 orderId){
        address tokenB = CErc20Interface(createParams.ctokenB).underlying();
        commonCheck(orderOwner, createParams.stopHighPairPrice, createParams.stopLowPairPrice, createParams.amountA, createParams.expiryDate, createParams.leverage, createParams.ctokenA, VETH,tokenB);
        uint256[] memory amounts =  swapETHToERC20(tokenB, calcSwapAmount(createParams.amountA, createParams.leverage),getAmountOutMin(createParams));
        orderId = onOrderCreate(orderOwner,createParams,amounts,VETH,tokenB);
    }

  

    /**
     * @dev save order and emit event
     *
     * @return orderId
     */
    function onOrderCreate(address orderOwner,CreateParams memory createParams,uint256[] memory amounts, address tokenA,address tokenB) internal returns (bytes32 orderId) {
        subAndSaveBalance(orderOwner, tokenA, createParams.amountA);
        subAndSaveLeverageBalance(orderOwner, tokenA, createParams.amountA.mul(createParams.leverage - 1));
        addAndSaveBalance(orderOwner, tokenB, amounts[1]);
        orderId = keccak256(abi.encode(orderOwner, createParams.amountA, tokenA, tokenB, getRandom()));
        emit OnTokenSwapped(orderId, orderOwner, tokenA, tokenB, amounts[0], amounts[1]);
        {
            Order memory order = Order(orderOwner, createParams.ctokenA, tokenA, tokenB, createParams.amountA, amounts[1], createParams.stopHighPairPrice, createParams.stopLowPairPrice, createParams.expiryDate, createParams.leverage);
            orders[orderId] = order;
        }
        emit OnOrderCreated(orderId, orderOwner, tokenA, createParams.ctokenA, tokenB, createParams.amountA, createParams.stopHighPairPrice, createParams.stopLowPairPrice, createParams.expiryDate, createParams.leverage, getPairPrice(tokenA,baseToken), getPairPrice(tokenB,baseToken));
    }



    function getRealToken(address token) internal view returns(address real) {
        if(token == VETH){
            IPangolinRouter router  = IPangolinRouter(_router());
            real =  router.WAVAX();
         }else{
             real = token;
         }
    }

    /**
     * @dev calculate the real amount to swap
     *
     * @param amountA               The token A amount
     * @param leverage              leverage
     *
     * @return swapAmount
     */
    function calcSwapAmount(uint256 amountA,uint8 leverage) internal view returns(uint256 swapAmount){
        uint256 amountAddLeverage = amountA.mul(leverage);
        swapAmount = amountAddLeverage.sub(amountAddLeverage.mul(serviceFee).div(1e18));
    }

    /**
     * @dev check the token's allowance and transfer to current contract
     * @param owner       The address of token owner
     * @param token       The address of token
     * @param amount      The transfer amount of token
     */
    function checkAllowance(address owner,address token,uint256 amount,uint8 leverage) view internal{
            uint256 allowance1 = _assetBooks[token].accountBalance[owner];
            uint256 leverageAmount = amount.mul(leverage - 1);
            uint256 allowance2 = _assetBooks[token].accountLeverageBalance[owner];
            require(allowance1 >= amount && allowance2 >= leverageAmount, "allowance error");
    }

     /**
     * @dev check the token's allowance and transfer to current contract
     * @param owner       The address of token owner
     * @param token       The address of token
     * @param amount      The transfer amount of token
     */
    function checkAllowance(address owner,address token,uint256 amount) view internal{
            uint256 allowance1 = _assetBooks[token].accountBalance[owner];
            require(allowance1 >= amount, "allowance error");
    }

    /**
     * @dev accumulation platform fees
     * @param token       The address of token
     * @param amount      The transfer amount of token
     * @param leverage    leverage
     */
    function addPlatformFees(address token, uint256 amount, uint8 leverage) internal nonReentrant{
        platformFees[VETH] += originFee;
        platformFees[token] += amount.mul(leverage).mul(serviceFee).div(1e18);
    }

    /**
     * @dev withdraw platform fees
     * @param tokens token list 
     */
    function withdrawPlatformFees(address[] memory tokens) external onlyAdmin nonReentrant{
        for(uint i = 0; i < tokens.length; i++){
            address token = tokens[i];
            uint256 amount = platformFees[token];
            if(amount == 0){
                continue;
            }
            if(token == VETH){
                payable(msg.sender).transfer(amount);
            }else{
                IERC20(token).safeTransfer(msg.sender, amount);
            }
            platformFees[token] = 0;
            emit OnWithdrawPlatformFee(token, amount);
        }
    }

    /**
     * @dev the commom require check when order creating
     * @param orderOwner             The address of order owner
     * @param stopHighPairPrice      limit token pair price
     * @param stopLowPairPrice       stop token pair price
     * @param amountA                The token A amount
     * @param expiryDate             expiry date
     * @param leverage               leverage
     */
    function commonCreateRequire(address orderOwner, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 amountA, uint256 expiryDate,uint8 leverage, address tokenB,address ctokenA) internal {
        require(ctokenA != address(0), "invalid ctoken");
        require(ctokenA == msg.sender,"ctokenA error");
        require(hasRole(VEETOKEN_ROLE, msg.sender), "VEETOKEN required");
        require(orderOwner != address(0), "invalid order owner");
        require(baseToken != address(0), "invalid baseToken");
        require(stopHighPairPrice != 0, "invalid limit price");
        require(stopLowPairPrice != 0, "invalid stop limit");
        require(amountA != 0, "amountA can't be zero.");
        uint256 expire = expiryDate.sub(block.timestamp);
        require(expire < maxExpire, "expirydate error");
        require(leverage > 0 && leverage <= maxLeverage,"leverage incorrect");
        require(msg.value == originFee,"originFee incorrect");
        require(whiteList[tokenB],"whiteList error");
        bool outOfLimit = amountA.mul(leverage).mul(IPriceOracle(oracle).getUnderlyingPrice(ctokenA)).div(1e18) > sizeLimit;
        require(!outOfLimit,"out of limit");

    }

    function commonCheck(address orderOwner,uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 amountA, uint256 expiryDate, uint8 leverage, address ctokenA, address tokenA,address tokenB) internal {
        require(tokenA != address(0), "invalid tokenA");
        commonCreateRequire(orderOwner, stopHighPairPrice, stopLowPairPrice, amountA, expiryDate, leverage, tokenB, ctokenA);
        addPlatformFees(tokenA, amountA, leverage);
        checkAllowance(orderOwner,tokenA,amountA,leverage);
    }

    function getAmountOutMin(CreateParams memory createParams) internal returns(uint256 amountOutMin) {
        address tokenA = getUnderlying(createParams.ctokenA);
        address tokenB = getUnderlying(createParams.ctokenB);
        uint256 priceA = IPriceOracle(oracle).getUnderlyingPrice(createParams.ctokenA);
        uint256 priceB = IPriceOracle(oracle).getUnderlyingPrice(createParams.ctokenB);
        uint256 swapAmountA = calcSwapAmount(createParams.amountA, createParams.leverage);
        uint256 amountFromOracle = priceA * swapAmountA / priceB;
        uint256 amountOut = getAmountOut(tokenA, tokenB, swapAmountA);
        amountOutMin = amountFromOracle * 95 / 100;
        bool isRightPrice = amountOut >= amountOutMin;
        require(isRightPrice,"price error");
    }

    function getUnderlying(address ctoken) internal returns(address underlying) {
        if(ctoken == _cether){
            underlying = VETH;
        }else{
            underlying = CErc20Interface(ctoken).underlying();
        }
    } 


    function getTokenDecimals(address token) internal view returns(uint256 decimals) {
        if(token == VETH){
            decimals = uint256(10)**18;
        }else{
            decimals = uint256(10)**IERC20(token).decimals();
        }
    }

     /**
     * @dev check if the stop-limit order is expired or should be executed if the price reaches the stop/limit pair price.
     *
     * @param orderId  The order id
     *
     * @return status code:
     *                     StateCode.EXECUTE: execute.
     *                     StateCode.EXPIRED: expired.
     *                     StateCode.NOT_RUN: not yet reach limit or stop.
     */
    function checkOrder(bytes32 orderId) external returns (uint8) {
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0), "invalid order id");
        uint256 price = getTokenA2TokenBPrice(order.tokenA, order.tokenB);
        uint256 stopLowPrice = getStopLowPrice(order.tokenA, order.tokenB, order.amountA, order.amountB, order.stopLowPairPrice, order.leverage);
        if(order.expiryDate <= block.timestamp){
            return (uint8(StateCode.EXPIRED));
        }
        if(price <= stopLowPrice || price >= order.stopHighPairPrice){
            return (uint8(StateCode.EXECUTE));
        }
        return (uint8(StateCode.NOT_RUN));
    }

    /**
     * @dev the commom require check when order creating
     * @param tokenA             The address of token A
     * @param tokenB             The address of token B
     * @param amountA            token A amount
     * @param amountB            token B amount
     * @param stopLowPairPrice   stop token pair price
     * @param leverage           leverage
     * @return stopLowPrice
     */
    function getStopLowPrice(address tokenA,address tokenB,uint256 amountA,uint256 amountB,uint256 stopLowPairPrice,uint8 leverage) internal view returns(uint256 stopLowPrice){
        if(leverage == 1){
            stopLowPrice = stopLowPairPrice;
        }else{
            uint256 averagePrice = calcAveragePrice(tokenA, tokenB, amountA, amountB, leverage);
            stopLowPrice = averagePrice.mul(uint256(1e18).sub(marginRate.div(leverage))).div(1e18);
            if(stopLowPrice < stopLowPairPrice){
                stopLowPrice = stopLowPairPrice;
            }    
        } 
    }

    /**
     * @dev calculate average price
     * @param tokenA             The address of token A
     * @param tokenB             The address of token B
     * @param amountA            token A amount
     * @param amountB            token B amount
     * @param leverage           leverage
     * @return averagePrice
     */
    function calcAveragePrice(address tokenA,address tokenB,uint256 amountA,uint256 amountB,uint8 leverage) internal view returns(uint256 averagePrice){
        uint256 swapAmount = calcSwapAmount(amountA,leverage);
        uint256 decimalsA = getTokenDecimals(tokenA);
        uint256 decimalsB = getTokenDecimals(tokenB);
        averagePrice = swapAmount.mul(1e18).mul(decimalsB).div(amountB).div(decimalsA);   
    }

    /**
     * @dev cancel a valid order.
     *
     * @param orderId  The order id
     *
     * @return Whether or not the canceling order succeeded
     *
     */
    function cancelOrder(bytes32 orderId) external onlyExecutor nonReentrant veeLock(uint8(VeeLockState.LOCK_CANCELORDER)) returns(bool){
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0), "invalid order id");
        uint256 price = getTokenA2TokenBPrice(order.tokenA, order.tokenB);
        uint256[] memory amounts = closeOrder(orderId);
        emit OnOrderCanceled(orderId, amounts[0], amounts[1], order.stopLowPairPrice, order.stopHighPairPrice, price, getPairPrice(order.tokenA,baseToken), getPairPrice(order.tokenB,baseToken));
        return true;
    }


        /**
     * @dev execute order if the stop-limit order is expired or should be executed if the price reaches the stop/limit value.
     *
     * @param orderId  The order id
     *
     * @return true: success, false: failure.
     *
     */
    function executeOrder(bytes32 orderId) external onlyExecutor nonReentrant veeLock(uint8(VeeLockState.LOCK_EXECUTEDORDER)) returns (bool){
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0),"invalid order id");
        require(order.expiryDate > block.timestamp,"expiryDate");
        uint256 price = getTokenA2TokenBPrice(order.tokenA, order.tokenB);
        uint256 stopLowPrice = getStopLowPrice(order.tokenA, order.tokenB, order.amountA, order.amountB, order.stopLowPairPrice, order.leverage);
        require(price <= stopLowPrice || price >= order.stopHighPairPrice,"price not met");
        uint256[] memory amounts = closeOrder(orderId);
        emit OnOrderExecuted(orderId, amounts[0], amounts[1], order.stopLowPairPrice, order.stopHighPairPrice, price, getPairPrice(order.tokenA,baseToken), getPairPrice(order.tokenB,baseToken));
        return true;
    }

    function closeOrder(bytes32 orderId) internal returns(uint256[] memory amounts){
        Order memory order = orders[orderId];
        checkAllowance(order.orderOwner, order.tokenB, order.amountB);
        if(order.tokenA != VETH && order.tokenB != VETH ){
            amounts = swapERC20ToERC20(order.tokenB, order.tokenA, order.amountB,1);
        }else  if(order.tokenA == VETH && order.tokenB != VETH ){
            amounts = swapERC20ToETH(order.tokenB, order.amountB,1);
        }else{
            amounts = swapETHToERC20(order.tokenA, order.amountB,1);
        }
        require(amounts[1] != 0, "close error");
        settlementOrder(orderId, amounts,order);        
    }

    /**
     * @param orderId  The order id
     * @param amounts  The swap result
     */
    function settlementOrder(bytes32 orderId,uint256[] memory amounts,Order memory order) internal returns(bool){
        subAndSaveBalance(order.orderOwner, order.tokenB, order.amountB);
        uint256 newAmountA = amounts[1];
        (uint256 borrowRemains,uint256 leverageRemains) = getBorrowRemains(order);
        uint256 profit = repayLeverageAndBorrow(order, newAmountA, borrowRemains, leverageRemains);
        if(profit > 0){
            transferProfit(order, profit);
        }
        delete orders[orderId];
        return true;
    }

    /**
     * @dev set executor role by administrator.
     *
     * @param newExecutor  The address of new executor
     *
     */
    function setExecutor(address newExecutor) external onlyAdmin {
        require(newExecutor != address(0), "address invalid");
        grantRole(EXECUTOR_ROLE, newExecutor);
   }

    /**
     * @dev remove an executor role from the list by administrator.
     *
     * @param executor  The address of an executor
     *
     */
    function removeExecutor(address executor) external onlyAdmin {
        require(executor != address(0), "address invalid");
        revokeRole(EXECUTOR_ROLE, executor);
    }

    /**
     * @dev set new cETH by administrator.
     *
     * @param ceth The address of an cETH
     *
     */
    function setCETH(address ceth) external onlyAdmin {
        require(ceth != address(0), "invalid token");
        _cether = ceth;
    }

     /**
     * @dev set new UNISWAP router by administrator.
     *
     */
    function setRouter(address newRouter) external onlyAdmin {
        require(newRouter != address(0), "invalid router");
        address oldRouter = _router();
        _setRouter(newRouter);
        emit NewRouter(address(oldRouter), newRouter);
    }


    /**
     * @param order order
     * @param newAmountA the amount a from dex
     * @param borrowRemains borrow balance remains
     * @param leverageRemains leverage balance remains
     * @return profit amount
     */
    function repayLeverageAndBorrow(Order memory order,uint256 newAmountA,uint256 borrowRemains,uint256 leverageRemains) internal returns(uint256){
        uint256 expectLeverageAmount = order.amountA.mul(order.leverage-1);
        uint256 realLeverageAmount = min(newAmountA,expectLeverageAmount,leverageRemains);
        uint256 newAmountARemains = newAmountA.sub(realLeverageAmount);
        uint256 repayAmount = min(newAmountARemains,order.amountA,borrowRemains);
        uint256 repayValue = repayAmount.add(realLeverageAmount);
        uint err;
        if(order.tokenA == VETH){
            (err,) = CEtherInterface(order.ctokenA).repayLeverageAndBorrow{value:repayValue}(order.orderOwner,repayAmount,expectLeverageAmount, realLeverageAmount);
        }else{
            require(IERC20(order.tokenA).approve(order.ctokenA, repayValue),"failed to approve");
            (err,)=CErc20Interface(order.ctokenA).repayLeverageAndBorrow(order.orderOwner, repayAmount, expectLeverageAmount, realLeverageAmount);
        }
        require(err == 0,"repay error");
        return newAmountA.sub(repayAmount).sub(realLeverageAmount);

    }

    function min(uint256 amount1,uint256 amount2,uint256 amount3) internal pure returns(uint256){
        uint256 temp;
        if(amount1 > amount2){
            temp = amount2;
        }else {
            temp = amount1;
        }
        if(temp > amount3){
            temp = amount3;
        }
        return temp;
    }

    /**
     * @dev get order borrow and leverage amount should be repay
     * @param order order
     */
    function getBorrowRemains(Order memory order) internal view returns (uint256 borrowRemains,uint256 leverageRemains){
        uint256 borrowedTotal = CTokenInterface(order.ctokenA).borrowBalanceStored(order.orderOwner);
        uint256 leverageTotal = CTokenInterface(order.ctokenA).accountLeverage(order.orderOwner);
        if(borrowedTotal < order.amountA){
            borrowRemains = borrowedTotal;
        }else{
            borrowRemains = order.amountA;
        }
        uint256 leverage = order.amountA.mul(order.leverage - 1);
        if(leverageTotal < leverage){
            leverageRemains = leverageTotal;
        }else{
            leverageRemains = leverage;
        }
    }

    /**
     * @dev transfer profit
     *
     * @param order order
     * @param profit amount of profit
     *
     */
    function transferProfit(Order memory order, uint256 profit) internal returns (bool){
        if(profit == 0){
            return true;
        }
        if(order.tokenA == VETH){
            payable(order.orderOwner).transfer(profit);
        }else{
            IERC20(order.tokenA).safeTransfer(order.orderOwner, profit);
        }
        emit TransferProfit(order.tokenA, order.tokenB, profit);
        return true;
    }

   /**
     * @dev swap ERC20 to ETH token in DEX UNISWAP.
     *
     * @param tokenA      The address of token A
     * @param amountA     The token A amount
     *
     * @return memory: The input token amount and all subsequent output token amounts.
     *
     */
    function swapERC20ToETH(address tokenA, uint256 amountA,uint256 amountOutMin) internal returns (uint256[] memory){
        bytes memory data = delegateTo(swapHelper, abi.encodeWithSignature("swapERC20ToETH(address,uint256,uint256)", tokenA, amountA,amountOutMin));
        uint256[] memory amounts = abi.decode(data, (uint256[]));
        return amounts;
    }

    /**
     * @dev swap ETH to ERC20 token in DEX UNISWAP.
     *
     * @param tokenB      The address of token B
     * @param amountA     The eth amount  A
     *
     * @return memory: The input token amount and all subsequent output token amounts..
     *
     */
    function swapETHToERC20(address tokenB, uint256 amountA,uint256 amountOutMin) internal returns (uint256[] memory){
        bytes memory data = delegateTo(swapHelper, abi.encodeWithSignature("swapETHToERC20(address,uint256,uint256)", tokenB, amountA,amountOutMin));
        uint256[] memory amounts = abi.decode(data, (uint256[]));
        return amounts;
    }

    /**
     * @dev swap ERC20 to ERC20 token in DEX UNISWAP.
     *
     * @param tokenA      The address of token A
     * @param swapAmount     The token A amount
     * @param tokenB      The address of token B
     *
     * @return memory: The input token amount and all subsequent output token amounts.
     *
     */
    function swapERC20ToERC20(address tokenA, address tokenB, uint256 swapAmount,uint256 amountOutMin) internal returns (uint256[] memory){
        bytes memory data = delegateTo(swapHelper, abi.encodeWithSignature("swapERC20ToERC20(address,address,uint256,uint256)", tokenA, tokenB, swapAmount,amountOutMin));
        uint256[] memory amounts = abi.decode(data, (uint256[]));
        return amounts;
    }

     /**
     * @dev calculate token pair price.
     *
     * @param tokenA   The address of token A
     * @param tokenB   The address of token B
     *
     * @return price
     *
     */
     function getPairPrice(address tokenA, address tokenB) internal returns(uint256 price){
        bytes memory data = delegateTo(swapHelper, abi.encodeWithSignature("getPairPrice(address,address)", tokenA,tokenB));
        price = abi.decode(data, (uint256));
    }

    /**
     * @param tokenA tokenA address
     * @param tokenB tokenB address
     * @return price (price tokenA per tokenB)
     */
    function getTokenA2TokenBPrice(address tokenA, address tokenB) internal returns(uint256 price){
        tokenA = getRealToken(tokenA);
        tokenB = getRealToken(tokenB);
        bytes memory data = delegateTo(swapHelper, abi.encodeWithSignature("getTokenA2TokenBPrice(address,address)", tokenB, tokenA));
        price = abi.decode(data,(uint256));
    }

    function getAmountOut(address tokenA, address tokenB,uint256 amountIn) internal view returns(uint256 amountOut){
        IPangolinRouter UniswapV2Router = IPangolinRouter(_router());
        IUniswapV2Factory UniswapV2Factory = IUniswapV2Factory(UniswapV2Router.factory());
        tokenA = getRealToken(tokenA);
        tokenB = getRealToken(tokenB);
        address factoryAddress = UniswapV2Factory.getPair(tokenA, tokenB);
        require(factoryAddress != address(0), "token pair error");
        IUniswapV2Pair UniswapV2Pair = IUniswapV2Pair(factoryAddress);
        (uint Res0, uint Res1,) = UniswapV2Pair.getReserves();
        if (tokenA < tokenB) {
            amountOut = UniswapV2Router.getAmountOut(amountIn, Res0, Res1);
        } else {
            amountOut = UniswapV2Router.getAmountOut(amountIn, Res1, Res0);
        }
        require(amountOut != 0, "error PairPrice");
    }


    /*** Private Functions ***/
    /**
     * @dev generate random number.
     *
     */
   function getRandom() private returns (uint256) {
       nonce++;
       uint256 randomnumber = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) ;
       randomnumber = randomnumber + 1;
       return randomnumber;
    }

    /**
     * @dev deposit assets
     *
     * @param account address of user account
     * @param token erc20 token address or address(0) stands for AVAX
     *
     */
    function deposit(address account, address token, uint256 accountAmount,uint8 leverage) external payable nonReentrant {
        require(hasRole(VEETOKEN_ROLE, msg.sender) || hasRole(EXECUTOR_ROLE, msg.sender), "deposit deny");
        require(account != address(0), "account error");
        require(token != address(0) || msg.value > 0, "token missed");
        require(leverage > 0 && leverage <= maxLeverage,"leverage incorrect");
        uint256 leverageAmount = accountAmount.mul(leverage-1);
        uint256 amountSum = accountAmount.add(leverageAmount);
        if (msg.value == 0) {
            IERC20 erc20Token = IERC20(token);
            uint256 allowance = erc20Token.allowance(msg.sender, address(this));
            require(allowance >= amountSum, "allowance not enough");
            erc20Token.safeTransferFrom(msg.sender, address(this), amountSum);
            uint256 newTotalBalance = addAndSaveBalance(account, token, accountAmount);
            addAndSaveLeverageBalance(account, token, leverageAmount);
            emit Deposit(account, token, newTotalBalance, accountAmount,leverageAmount);
        } else {
            require(amountSum == msg.value,"value is error");
            uint256 newTotalBalance = addAndSaveBalance(account, VETH, accountAmount);
            addAndSaveLeverageBalance(account, VETH, leverageAmount);
            emit Deposit(account, token, newTotalBalance, accountAmount,leverageAmount);
        }
        addToMarketInternal(token, account);
    }

    /**
     * @dev add token to user asset list
     *
     * @param token token address
     * @param borrower address of user account
     *
     */
    function addToMarketInternal(address token, address borrower) internal returns (bool) {
        AssetBook storage assetBook = _assetBooks[token];
        if (assetBook.assetMember[borrower] == true) {
            return true;
        }
        assetBook.assetMember[borrower] = true;
        accountAssets[borrower].push(token);
        return true;
    }

    /**
     * @dev get deposited balance by token and account
     *
     * @param account address of user account
     * @param token token address
     *
     */
    function getAccountAssetBalance(address account, address token) external view returns(uint amount, uint leverageAmount) {
        amount = _assetBooks[token].accountBalance[account];
        leverageAmount = _assetBooks[token].accountLeverageBalance[account];
    }

    /**
     * @dev get user deposited asset list
     *
     * @param account address of user account
     *
     */
    function getAssetsIn(address account) external view returns(address[] memory) {
        return accountAssets[account];
    }

    /**
     * @param owner account address
     * @param token token address
     * @param amount amount to subtract
     * @return balance after subtract
     */
    function subAndSaveBalance(address owner, address token, uint256 amount) internal returns (uint256) {
        (bool noError, uint256 newTotalBalance) = SafeMath.trySub(_assetBooks[token].accountBalance[owner], amount);
        require(noError, "subBalance error");
        _assetBooks[token].accountBalance[owner] = newTotalBalance;
        return newTotalBalance;
    }

    /**
     * @param owner account address
     * @param token token address
     * @param leverageAmount amount to subtract
     */
    function subAndSaveLeverageBalance(address owner, address token, uint256 leverageAmount) internal {
        (bool noError2,uint256 newTotalLeverage) = SafeMath.trySub(_assetBooks[token].accountLeverageBalance[owner], leverageAmount);
        require(noError2, "subLeverage error");
        _assetBooks[token].accountLeverageBalance[owner] = newTotalLeverage;
    }

    /**
     * @param owner account address
     * @param token token address
     * @param amount amount to add
     * @return balance after added
     */
    function addAndSaveBalance(address owner, address token, uint256 amount) internal  returns (uint256) {
        (bool noError, uint256 newTotalBalance) = SafeMath.tryAdd(_assetBooks[token].accountBalance[owner], amount);
        require(noError, "addBalance error");
         _assetBooks[token].accountBalance[owner] = newTotalBalance;
        return newTotalBalance;
    }

    /**
     * @param owner account address
     * @param token token address
     * @param leverageAmount amount to add
     */
    function addAndSaveLeverageBalance(address owner, address token,uint256 leverageAmount) internal  {
        (bool noError2,uint256 newTotalLeverage) = SafeMath.tryAdd(_assetBooks[token].accountLeverageBalance[owner], leverageAmount);
        require(noError2, "addLeverage error");
        _assetBooks[token].accountLeverageBalance[owner] = newTotalLeverage;
    }

    /**
     * @dev delegatecall to remote contract
     * @param callee remote contract address to call
     * @param data calldata
     * @return returndata
     */
    function delegateTo(address callee, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
        return returnData;
    }


     /**
     * @dev set SwapHelper address
     */
    function setSwapHelper(address newSwapHelper) external onlyAdmin {
        require(newSwapHelper != address(0), "invalid swaphelper");
        address oldSwapHelper = swapHelper;
        swapHelper = newSwapHelper;
        emit NewSwapHelper(oldSwapHelper, newSwapHelper);
    }

    /**
     * @dev set dex router address
     *
     * @param newRouter dex router address
     */
    function _setRouter(address newRouter) internal {
        bytes32 slot = ROUTER_SLOT;
        assembly {
          sstore(slot, newRouter)
        }
    }


    /**
     * @dev get dex router address
     *
     * @return impl dex router address
     */
    function getRouter() external view returns(address impl) {
        return _router();
    }

    /**
     * @dev get dex router address internal
     *
     * @return impl dex router address
     */
    function _router() internal view returns(address impl) {
        bytes32 slot = ROUTER_SLOT;
        assembly {
          impl := sload(slot)
        }
    }

    /**
     * @dev update service fee
     *
     */
    function setServiceFee(uint256 _serviceFee) external onlyAdmin {
        require(_serviceFee!=0,"invalid serviceFee");
        uint256 oldServiceFee = serviceFee;
        serviceFee = _serviceFee;
        emit NewServiceFee(oldServiceFee, serviceFee);
    }

    /**
     * @dev update origin fee
     *
     */
    function setOriginFee(uint256 _originFee) external onlyAdmin {
        require(_originFee!=0,"invalid originFee");
        uint256 oldOriginFee = originFee;
        originFee = _originFee;
        emit NewOriginFee(oldOriginFee, originFee);
    }

    /**
     * @dev update max leverage
     *
     */
    function setMaxleverage(uint8 newMaxLeverage) external onlyAdmin {
        require(newMaxLeverage!=0,"invalid leverage");
        uint8 oldMaxLeverage = maxLeverage;
        maxLeverage = newMaxLeverage;
        emit NewMaxLeverage(oldMaxLeverage, newMaxLeverage);
    }

    /**
     * @dev update oracle
     *
     */
    function setOracle(address newOracle) external onlyAdmin{
        address oldOracle = oracle;
        oracle = newOracle;
        emit NewOracle(oldOracle, newOracle);
    }

    function add2WhiteList(address[] memory _whiteList) external onlyAdmin {
        _add2WhiteList(_whiteList);
    }

    function _add2WhiteList(address[] memory _whiteList) internal {
        for(uint256 i = 0; i < _whiteList.length; i++){
            whiteList[_whiteList[i]] = true;
            emit WhiteListChanged(0,_whiteList[i]);
        }
    }

    function removeFromWhiteList(address[] memory _whiteList) external onlyAdmin {
        for(uint256 i = 0; i < _whiteList.length; i++){
            whiteList[_whiteList[i]] = false;
            emit WhiteListChanged(1,_whiteList[i]);
        }
    }

    function setSizeLimit(uint256 _sizeLimit) external onlyAdmin {
        uint256 oldLimit = sizeLimit;
        sizeLimit = _sizeLimit;
        emit NewSizeLimit(oldLimit, sizeLimit);
    }

}
