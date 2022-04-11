from brownie import accounts, interface

uniswapV2_router = interface.UniswapRouterV2(
    '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D')
uniswapV2_factory = interface.UniswapFactory(
    '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f')
babydoge_token = interface.BabyDogeToken(
    '0xac8e13ecc30da7ff04b842f21a62a1fb0f10ebd5')
weth = interface.WETH('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2')
pair = interface.UniswapPair(
    uniswapV2_factory.getPair(babydoge_token, weth))
