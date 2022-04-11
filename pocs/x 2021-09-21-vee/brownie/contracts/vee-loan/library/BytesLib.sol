// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16 <0.9.0;

library BytesLib {
    function concatBytesSig(bytes4 signature, bytes memory data1, bytes memory data2) internal pure returns(bytes memory combined) {
        bytes memory tempBytes;
        assembly {
            tempBytes := mload(0x40)

            let length := mload(data1)
            mstore(tempBytes, length)

            let mc := add(tempBytes, 0x20)
            mstore(mc, signature)
            mc := add(mc, 4)
            let end := add(mc, length)

            for {
                let cc := add(data1, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            length := mload(data2)
            mstore(tempBytes, add(4, add(length, mload(tempBytes))))

            mc := end
            end := add(mc, length)

            for {
                let cc := add(data2, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            mstore(0x40, and(
              add(add(end, iszero(add(4, add(length, mload(data1))))), 31),
              not(31) // Round down to the nearest 32 bytes.
            ))
        }

        return tempBytes;
    }
}