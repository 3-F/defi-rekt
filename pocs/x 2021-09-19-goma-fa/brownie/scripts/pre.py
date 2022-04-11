from brownie import accounts, interface, chain, GOMA
owner = accounts[0]
goma = GOMA.deploy({'from': owner})
pair = interface.IPancakePair(goma.pancakeSwapV2Pair())
router = interface.IPancakeRouter('0x10ED43C718714eb63d5aA57B78B54704E256024E')
goma.approve(router, (1<<256)-1, {'from': owner})
router.addLiquidityETH(goma, 47831140710616722263839, 0, 0, owner, chain.time() + 120, {'from': owner, 'value': 1183775869589480869356})

def main():
    owner = accounts[0]
    goma = GOMA.deploy({'from': owner})
    pair = interface.IPancakeRouter(goma.pancakeSwapV2Pair())
    router = interface.IPancakeRouter('0x10ED43C718714eb63d5aA57B78B54704E256024E')
    goma.approve(router, (1<<256)-1, {'from': owner})
    router.addLiquidityETH(goma, 47831140710616722263839, 0, 0, owner, chain.time() + 120, {'from': owner, 'value': 1183775869589480869356})
