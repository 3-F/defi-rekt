pragma solidity >=0.4.22;

interface IUniswapV1Pair {
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns(uint256 amount);
}
