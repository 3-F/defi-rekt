from brownie import accounts, interface, chain, BscRouterCollertor, web3

def main():
    user = accounts[0]
    pvm = interface.PVMToken('0x71afF23750db1f4edbE32C942157a478349035b2')
    wbnb = interface.WBNB('0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c')
    br = interface.BakerySwapRouter('0xCDe540d7eAFE93aC5fE6233Bee57E1270D3E330F')
    ar = interface.ApeRouter('0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607')
    pr = interface.PancakeRouter('0x10ED43C718714eb63d5aA57B78B54704E256024E')
    amounts = pr.getAmountsIn(2e7, [wbnb, pvm])
    l = BscRouterCollertor.deploy(pvm, ar, br, ar.factory(), br.factory(), {
        'from': user, 'value': (amounts[0] + 2e6) * 1.01, 'gasPrice': web3.toWei(0.000000005, 'ether')})
