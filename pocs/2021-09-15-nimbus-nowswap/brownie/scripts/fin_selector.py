from itertools import tee
import random
import string
from web3 import Web3
import time
def ranstr(num):
    salt = ''.join(random.sample(string.ascii_letters + string.digits, num))
    return salt

target = '48019769'
# while True:
start = time.time()
i = 0
while True:
    salt = ranstr(20)
    # print(salt, ' attemp times: ', i)
    if str(Web3.toHex(Web3.keccak(text=salt + '(address,uint,uint,bytes)')))[2:10] == target:
        print('find it: ', salt)
        break
    i += 1

end = time.time()
print(f'time spand is: {end - start}; attemp times: {i}')

with open('./selector.info', 'w') as f:
    f.write('salt is: ' + salt + '\ntime spend: ' + str(end - start))

# table = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIZKLMNOPQRSTUVWXYZ'
