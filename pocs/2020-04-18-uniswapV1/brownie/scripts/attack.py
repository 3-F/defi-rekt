from brownie import accounts, interface, Luck
from brownie.network import web3


def main():
    user = accounts[0]
    luck = Luck.deploy(2, {
        'from': user
    })
    old_balance = user.balance()
    luck.good_luck({
        'from': user,
        'value': web3.toWei(100, 'ether')
    })
    luck.withdraw({
        'from': user
    })
    print('profit:', user.balance()-old_balance)
