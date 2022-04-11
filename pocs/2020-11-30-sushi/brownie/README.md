### analyze.py

Analyzing Fee reserved in SushiMaker contract with different blocks.

### attack.py

A PoC about SushiMaker incidience, taking YFI/WETH for an instance.

### attack1.py

The complete script of exploiting SushiMaker.

- step 1: obtain all pairs in SushiSwap

- step 2: sort this pairs by price (base ETH) and reserve in SushiMaker

- step 3: exploit one by one, calculate total profits

### attack_contract.py

Expolit SushiMaker with main logic writing in smart contract.

### Challenge
- Q1: Non-standard ERC20 token

Solution: using openzeppelin library -- SafeERC20

- Q2: How many SLP' should be minted