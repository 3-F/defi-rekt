from brownie import accounts, interface
import json
from tqdm import tqdm
'''
{
    "pair_addr": {
        "token0": {
            "addr: _,
            "symbol": _,
            "reserve_in_pair": _,
            "pairs[pair][token]": _,
            "balanceOf(router)": _ 
        },
        "token1": {
            "addr: _,
            "symbol": _,
            "reserve_in_pair": _,
            "pairs[pair][token]": _,
            "balanceOf(router)": _ 
        },
    }
}
'''

def main():
    user = accounts[0]
    router = interface.ISashimiRouter('0xe4FE6a45f354E845F954CdDeE6084603CEDB9410')
    factory = interface.ISashimiFactory('0xF028F723ED1D0fE01cC59973C49298AA95c57472')
    len_all_pairs = factory.allPairsLength()
    all_pairs = []
    for i in tqdm(range(len_all_pairs)):
        all_pairs.append(interface.ISashimiPair(factory.allPairs(i)))
    print(f'All pairs in sashimiswap: {[p.address for p in all_pairs]}')
    res = {}
    for pair in tqdm(all_pairs):
        token0 = interface.ERC20(pair.token0())
        token1 = interface.ERC20(pair.token1())
        r0, r1, _ = pair.getReserves()
        res[pair.address] = {
            "token0": {
                "address": token0.address,
                "symbol": token0.symbol(),
                "pair_reserve": r0,
                "router_reserve": router.getTokenInPair(pair.address, token0.address),
                "balance_reserve": token0.balanceOf(router.address, {'from': user})
            },
            "token1": {
                "address": token1.address,
                "symbol": token1.symbol(),
                "pair_reserve": r1,
                "router_reserve": router.getTokenInPair(pair.address, token1.address),
                "balance_reserve": token1.balanceOf(router.address, {'from': user})
            }
        }
    with open('./data/agg.json', 'w') as f:
        json.dump(res, f)

    
