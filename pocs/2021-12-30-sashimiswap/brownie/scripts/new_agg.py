import re
from brownie import accounts, interface
import json
from tqdm import tqdm

def main():
    user = accounts[0]
    router = interface.ISashimiRouter('0xe4FE6a45f354E845F954CdDeE6084603CEDB9410')
    data = {}
    with open('./data/agg.json') as f:
        data = json.load(f)
    res = {}
    for p in tqdm(data.keys()):
        pair = interface.ISashimiPair(p)
        token0 = interface.ERC20(pair.token0())
        token1 = interface.ERC20(pair.token1())
        r0, r1, _ = pair.getReserves()
        res[pair.address] = {
            "token0": {
                "address": token0.address,
                "symbol": token0.symbol(),
                "pair_reserve": r0,
                "router_reserve": router.getTokenInPair(pair.address, token0.address),
                "balance_reserve": token0.balanceOf(router.address)
            },
            "token1": {
                "address": token1.address,
                "symbol": token1.symbol(),
                "pair_reserve": r1,
                "router_reserve": router.getTokenInPair(pair.address, token1.address),
                "balance_reserve": token1.balanceOf(router.address)
            }
        }
    
    print(res)

    with open('./data/pairs_latestls.json', 'w') as f:
        json.dump(res, f)