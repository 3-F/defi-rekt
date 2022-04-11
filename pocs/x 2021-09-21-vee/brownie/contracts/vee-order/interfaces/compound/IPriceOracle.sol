// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./CTokenInterfaces.sol";

abstract contract IPriceOracle {
    /// @dev Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;

    /**
      * @dev Get the underlying price of a cToken asset
      * @param cToken The cToken to get the underlying price of
      * @return The underlying asset price mantissa (scaled by 1e18).
      *  Zero means the price is unavailable.
      */
    function getUnderlyingPrice(CTokenInterface cToken) external view virtual returns (uint256);
}
