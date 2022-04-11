from asyncio.tasks import sleep
from logging import info
import threading
import web3
from web3 import Web3
import logging, time, json, asyncio
from collections import defaultdict
from threading import Thread

'''
AttributeDict({
    'address': '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c', 
    'topics': [
        HexBytes('0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'), 
        HexBytes('0x000000000000000000000000249a963e6632e539765ea9bd8e896f377b69bcee'), 
        HexBytes('0x00000000000000000000000010ed43c718714eb63d5aa57b78b54704e256024e')
        ], 
    'data': '0x0000000000000000000000000000000000000000000000000183e2d6d09a156b', 
    'blockNumber': 10856535, 
    'transactionHash': HexBytes('0xbabd656edd569165581d24aee41afe2e675fa0ddb1ccfedb832f4ddbfab45748'), 
    'transactionIndex': 135, 
    'blockHash': HexBytes('0xa6f3cc267c2b31b40d2534d3ea2e32aca53d53b1e2187639cfa3ef5c16e05bba'), 
    'logIndex': 530, 
    'removed': False})
'''
def check(profits, pr, wbnb):
    pass
    # for router, ts in profits.items():
    #     for t, profit in ts.items():
    #         if profit > 0:
    #             # reserve = ERC20(t).balanceOf(router)
    #             if reserve > 0:
    #                 value = pr.getAmountsOut(reserve, [t, wbnb])
    #                 return value > 3e16

async def log_loop(event_filter, poll_interval=0):

    while True:
        # now_block_number = w3.eth.block_number
        # if now_block_number > latest_block_number:
        #     # if check(profits, self.pr, wbnb):
        #     #     data = {}
        #     #     data['number'] = now_block_number
        #     #     data['profits'] = profits
        #     #     with open('./info.log', 'w') as f:
        #     #         json.dump(data, f)
        #     latest_block_number = now_block_number
        #     print(profits)
        #     profits = defaultdict(int)
        #     print(f'now is {now_block_number}')

        for event in event_filter.get_new_entries():
            print(event)
        await asyncio.sleep(poll_interval)
        #     router = str(Web3.toHex(event.topics[1]))
        #     token = event.address
        #     if token == wbnb:
        #         break
        #     profits[token] -= int(event.data, 16)

        # for event in rec_event_filter.get_new_entries():
        #     router = str(Web3.toHex(event.topics[2]))
        #     token = event.address
        #     if token == wbnb:
        #         break
        #     profits[token] += int(event.data, 16)


def router_handler(url, rec_event_filter, send_event_filter, router, poll_interval=0):
    w3 = Web3(web3.WebsocketProvider(url))
    # pr = interface.PancakeRouter('0x10ED43C718714eb63d5aA57B78B54704E256024E')
    wbnb = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'
    profits = defaultdict(int)
    latest_block_number = 0
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(
            asyncio.gather(
                log_loop(send_event_filter, 0),
                log_loop(rec_event_filter, 0)
            )
        )
    finally:
        loop.close()

    # time.sleep(poll_interval)

def main():
    url = 'wss://speedy-nodes-nyc.moralis.io/20189123bd8fd22f2ac08e16/bsc/mainnet/ws'
    # url_bk = 'https://bsc-dataseed.binance.org'
    w3 = Web3(web3.WebsocketProvider(url))

    with open('scripts/data/bsc_router_list.json', 'r') as f:
        bsc_router_list = json.load(f)
    with open('scripts/data/bsc_router_event_list.json', 'r') as f:
        bsc_router_event_list = json.load(f)
    with open('scripts/data/router_address.json', 'r') as f:
        bsc_routers = json.load(f)

    event_signature_hash = w3.keccak(text="Transfer(address,address,uint256)").hex()
    workers = []
    for router in bsc_router_event_list:
        print(router)
        rec_event_filter = w3.eth.filter({"topics": [event_signature_hash, None, router]})
        send_event_filter = w3.eth.filter({"topics": [event_signature_hash, router, None]})
        worker = Thread(target=router_handler, args=(url, rec_event_filter, send_event_filter, router), daemon=False)
        workers.append(worker)
        worker.start()

    for worker in workers:
        worker.join()

if __name__ == "__main__":
    main()
