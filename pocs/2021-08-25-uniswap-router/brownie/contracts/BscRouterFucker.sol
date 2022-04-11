pragma solidity ^0.8.0;

// Router like pancakeswap
interface IRouter1 {
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IRouter2 {
    function swapExactBNBForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactBNB(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidityBNB(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountBNBMin,
        address to,
        uint256 deadline
    )   external payable returns (uint256 amountToken, uint256 amountBNB, uint256 liquidity);

    function removeLiquidityBNBSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBNBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountBNB);
}
interface IBEP20 {
    function balanceOf(address account) external view returns(uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);
}

interface IFactory {
    function getPair(address _token0, address _token1) external view returns(address);
}

contract BscRouterCollertor {
    address constant private pancake_router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant private wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private owner;

    constructor(address _token, address _router1, address _router2, address _factory1, address _factory2) payable {
        owner = msg.sender;
        address[] memory path = new address[](2);
        path[0] = wbnb;
        path[1] = _token;
        IRouter1(pancake_router).swapETHForExactTokens{value: msg.value}(2e7, path, address(this), block.timestamp+120);
        
        IBEP20(_token).approve(_router1, type(uint).max);
        IBEP20(_token).approve(_router2, type(uint).max);
        IBEP20(_token).approve(pancake_router, type(uint).max);

        (,, uint amount) = IRouter1(_router1).addLiquidityETH{value: 1e6}(
            _token, 
            1e7, 
            0, 
            0, 
            address(this), 
             block.timestamp+120);
        address pair = IFactory(_factory1).getPair(_token, wbnb);
        IBEP20(pair).approve(_router1, type(uint).max);

        IRouter1(_router1).removeLiquidityETHSupportingFeeOnTransferTokens(
            _token, 
            amount / 6, 
            0, 
            0, 
            address(this), 
            block.timestamp+120);

        (,, amount) = IRouter2(_router2).addLiquidityBNB{value: 1e6}(
            _token, 
            1e7, 
            0, 
            0, 
            address(this), 
            block.timestamp+120);
        pair = IFactory(_factory2).getPair(_token, wbnb);
        IBEP20(pair).approve(_router2, type(uint).max);
        IRouter2(_router2).removeLiquidityBNBSupportingFeeOnTransferTokens(
            _token, 
            amount / 6, 
            0, 
            0, 
            address(this), 
            block.timestamp+120);

        path[0] = _token;
        path[1] = wbnb;
        IRouter1(pancake_router).swapExactTokensForETH(IBEP20(_token).balanceOf(address(this)), 0, path, msg.sender, block.timestamp+120);
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function batch_collect(address[] memory _tokens, address[] memory _routers, address[] memory _factorys, bool[] memory _types, uint _deadline) external payable onlyOwner {
        for (uint i = 0; i < _tokens.length; i++) {
            collect(_tokens[i], _routers[i], _factorys[i], _types[i], _deadline);
        }
    }

    function collect(address _token, address _router, address _factory, bool _type, uint _deadline) public payable onlyOwner {
        uint old_bal = address(this).balance;

        address pair = IFactory(_factory).getPair(_token, wbnb);
        bool noPair = pair == address(0);
        bool noLp = noPair || (IBEP20(pair).balanceOf(address(this)) == 0);
        address[] memory path = new address[](2);
        uint lpAmount;
        if (noLp) {
            path[0] = wbnb;
            path[1] = _token;
            IRouter1(pancake_router).swapETHForExactTokens{value: msg.value}(1e7, path, address(this), _deadline);
            
            if (IBEP20(_token).allowance(address(this), _router) == 0) {
                IBEP20(_token).approve(_router, type(uint).max);
            }
            if (IBEP20(_token).allowance(address(this), pancake_router) == 0) {
                IBEP20(_token).approve(pancake_router, type(uint).max);
            }
        } else {
            lpAmount = IBEP20(pair).balanceOf(address(this));
        }

        if (_type) {
            if (noLp) {
                (,, lpAmount) = IRouter1(_router).addLiquidityETH{value: 1e6}(
                    _token, 
                    IBEP20(_token).balanceOf(address(this)), 
                    0, 
                    0, 
                    address(this), 
                    _deadline);
                if (noPair) {
                    pair = IFactory(_factory).getPair(_token, wbnb);
                    IBEP20(pair).approve(_router, type(uint).max);
                }
            }

            IRouter1(_router).removeLiquidityETHSupportingFeeOnTransferTokens(
                _token, 
                lpAmount / 10, 
                0, 
                0, 
                address(this), 
                _deadline);
        } else {
            if (noLp) {
                (,, lpAmount) = IRouter2(_router).addLiquidityBNB{value: 1e6}(
                    _token, 
                    IBEP20(_token).balanceOf(address(this)), 
                    0, 
                    0, 
                    address(this), 
                    _deadline);
                if (noPair) {
                    pair = IFactory(_factory).getPair(_token, wbnb);
                    IBEP20(pair).approve(_router, type(uint).max);
                }
            }

            IRouter2(_router).removeLiquidityBNBSupportingFeeOnTransferTokens(
                _token, 
                lpAmount / 10, 
                0, 
                0, 
                address(this), 
                _deadline);
        }

        path[0] = _token;
        path[1] = wbnb;
        IRouter1(pancake_router).swapExactTokensForETH(IBEP20(_token).balanceOf(address(this)), 0, path, address(this), _deadline);
        require(address(this).balance > old_bal);
    }

    function hhh() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function over() external onlyOwner {
        selfdestruct(payable(owner));
    }

    receive() external payable {}
}