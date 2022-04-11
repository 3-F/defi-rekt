from collections import defaultdict
import sys
from eth_utils import address
import web3
from web3 import Web3
import asyncio
from ddbot import dd_report, AlertType
import time

async def log_loop(router, poll_interval=0):

    url = 'wss://speedy-nodes-nyc.moralis.io/20189123bd8fd22f2ac08e16/bsc/mainnet/ws'
    w3 = Web3(web3.WebsocketProvider(url, websocket_timeout=600, websocket_kwargs={'max_size': 3_000_000}))
    with open('./interfaces/BUSD.json', 'r') as f:
        erc20_abi = f.read()
    with open('./interfaces/PancakeRouter.json', 'r') as f:
        router_abi = f.read()
        
    event_signature_hash = w3.keccak(text="Transfer(address,address,uint256)").hex()
    event_filter = w3.eth.filter({
        "fromBlock": 'latest',
        "toBlock": 'latest',
        "topics": [event_signature_hash, None, None]})
    wbnb = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'

    profits = defaultdict(int)
    latest_block_number = 0
    router_topic = '0x000000000000000000000000' + router[2:]

    while True:
        try:
            for event in event_filter.get_new_entries():
                event_number = event.blockNumber
                src = str(Web3.toHex(event.topics[1]))
                dst = str(Web3.toHex(event.topics[2]))
                token = event.address
                if token == wbnb:
                    continue

                if src == router_topic:
                    profits[token] -= int(event.data, 16)
                elif dst == router_topic:
                    profits[token] += int(event.data, 16)

                if event_number > latest_block_number:
                    latest_block_number = event_number
                    for t in profits.keys():
                        if profits[t] > 1e16:
                            erc20 = w3.eth.contract(address=t, abi=erc20_abi)
                            balance_router = erc20.functions.balanceOf(Web3.toChecksumAddress(router)).call()
                            if balance_router > 1e16:
                                price = get_price(t, balance_router, router_abi, w3)
                                if price > 1e16:
                                    msg = f'block: {event_number} tx: {str(Web3.toHex(event.transactionHash))}, token, {token}, balance of router is: {balance_router}'
                                    print('[New finding]: ' + msg)
                                    dd_report(msg, AlertType.Urgent)
                    profits = defaultdict(int)
            await asyncio.sleep(poll_interval)
        except Exception as e:
            time.sleep(1)

def get_price(t, b, router_abi, w3):
    pancake_router = w3.eth.contract(address='0x10ED43C718714eb63d5aA57B78B54704E256024E', abi=router_abi)
    wbnb = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'
    return pancake_router.functions.getAmountsOut(b, [t, wbnb]).call()

def main(router):
    loop = asyncio.get_event_loop()

    try:

        loop.run_until_complete(
            asyncio.gather(log_loop(router, 1))
        )
    finally:
        loop.close()

if __name__ == '__main__':
    main(sys.argv[1])