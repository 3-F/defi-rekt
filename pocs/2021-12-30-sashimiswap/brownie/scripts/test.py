import re
from brownie import accounts, interface, ZERO_ADDRESS
import json
from tqdm import tqdm

def main():
    data = {}
    with open('./data/pairs_latest.json', 'r') as f:
        data = json.load(f)
        
    uni_factory = interface.ISashimiFactory('0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f')

    uni_router = interface.IUniswapV2Router02('0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D')

    weth = interface.ERC20('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2')

    tokens = set()
    for pair in tqdm(data.values()):
        tokens.add(pair['token0']['address'])
        tokens.add(pair['token1']['address'])

    weth_pair_tokens_uni = []

    for t in tqdm(list(tokens)):
        token = interface.ERC20(t)
        pair = uni_factory.getPair(weth, token)
        if pair == ZERO_ADDRESS:
            continue
        weth_pair_tokens_uni.append(pair)

    res = {}
    for p in tqdm(weth_pair_tokens_uni):
        pair = interface.ISashimiPair(p)
        token0 = interface.ERC20(pair.token0())
        token1 = interface.ERC20(pair.token1())
        r0, r1, _ = pair.getReserves()
        res[pair.address] = {
            "token0": {
                "address": token0.address,
                "symbol": token0.symbol(),
                "pair_reserve": r0
            },
            "token1": {
                "address": token1.address,
                "symbol": token1.symbol(),
                "pair_reserve": r1
            }
        }

    with open('./data/uni_reserve.json', 'w') as f:
        json.dump(res, f)