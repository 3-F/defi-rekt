// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import './SafeMath.sol';
library PreciseUnitMath {
    using SafeMath for uint256;
    uint256 constant internal PRECISE_UNIT = 10 ** 18;
    function preciseDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return a.mul(PRECISE_UNIT).div(b);
    }  
}