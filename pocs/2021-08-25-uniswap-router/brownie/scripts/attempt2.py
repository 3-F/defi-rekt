from os import times
from toolz.functoolz import thread_first
import web3
from web3 import Web3
from threading import Thread
import json
from collections import defaultdict
from ddbot import dd_report, AlertType
import time

def main(router):
    url = 'wss://speedy-nodes-nyc.moralis.io/20189123bd8fd22f2ac08e16/bsc/mainnet/ws'
    w3 = Web3(web3.WebsocketProvider(url, websocket_timeout=600, websocket_kwargs={'max_size': 3_000_000}))
    event_signature_hash = w3.keccak(text="Transfer(address,address,uint256)").hex()
    event_filter = w3.eth.filter({
        "fromBlock": 'latest',
        "toBlock": 'latest',
        "topics": [event_signature_hash, None, None]})

    with open('./interfaces/BUSD.json', 'r') as f:
        erc20_abi = f.read()
    profits = defaultdict(int)
    latest_block_number = 0
    router_topic = '0x000000000000000000000000' + router[2:]

    wbnb = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'

    while True:
        try:
            events = w3.eth.get_filter_changes(event_filter.filter_id)
        
            for event in events:
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
                                msg = f'block: {event_number} tx: {str(Web3.toHex(event.transactionHash))}, token, {token}, balance of router is: {balance_router}'
                                print('[New finding]: ' + msg)
                                dd_report(msg, AlertType.Urgent)
                    profits = defaultdict(int)
            # print(event_number)
        except Exception as e:
            time.sleep(1)

if __name__ == '__main__':
    with open('./scripts/data/bsc_router_list.json', 'r') as f:
        routers = json.load(f)

    workers = []
    for router in routers:
        worker = Thread(target=main, args=(router,))
        workers.append(worker)
        worker.start()

    for worker in workers:
        worker.join()