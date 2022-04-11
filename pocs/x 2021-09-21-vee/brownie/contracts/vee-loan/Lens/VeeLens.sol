pragma solidity >=0.8.0;
pragma experimental ABIEncoderV2;

import "../CErc20.sol";
import "../CToken.sol";
import "../PriceOracle.sol";
import "../EIP20Interface.sol";
import "../Governance/Vee.sol";

interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (CToken[] memory);
    function claimVee(address) external;
    function veeAccrued(address) external view returns (uint);
}
interface GovernorBravoInterface {
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }
    struct Proposal {
        uint id;
        address proposer;
        uint eta;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        uint abstainVotes;
        bool canceled;
        bool executed;
    }
    function getActions(uint proposalId) external view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas);
    function proposals(uint proposalId) external view returns (Proposal memory);
    function getReceipt(uint proposalId, address voter) external view returns (Receipt memory);
}

contract VeeLens {
    struct CTokenMetadata {
        address cToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint cTokenDecimals;
        uint underlyingDecimals;
    }

    function cTokenMetadata(CToken cToken) public returns (CTokenMetadata memory) {
        uint exchangeRateCurrent = cToken.exchangeRateCurrent();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(cToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(cToken.symbol(), "cETH")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            CErc20 cErc20 = CErc20(address(cToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
        }

        return CTokenMetadata({
            cToken: address(cToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: cToken.supplyRatePerBlock(),
            borrowRatePerBlock: cToken.borrowRatePerBlock(),
            reserveFactorMantissa: cToken.reserveFactorMantissa(),
            totalBorrows: cToken.totalBorrows(),
            totalReserves: cToken.totalReserves(),
            totalSupply: cToken.totalSupply(),
            totalCash: cToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            cTokenDecimals: cToken.decimals(),
            underlyingDecimals: underlyingDecimals
        });
    }

    function cTokenMetadataAll(CToken[] calldata cTokens) external returns (CTokenMetadata[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenMetadata[] memory res = new CTokenMetadata[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenMetadata(cTokens[i]);
        }
        return res;
    }

    struct CTokenBalances {
        address cToken;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
    }

    function cTokenBalances(CToken cToken, address payable account) public returns (CTokenBalances memory) {
        uint balanceOf = cToken.balanceOf(account);
        uint borrowBalanceCurrent = cToken.borrowBalanceCurrent(account);
        uint balanceOfUnderlying = cToken.balanceOfUnderlying(account);
        uint tokenBalance;
        uint tokenAllowance;

        if (compareStrings(cToken.symbol(), "cETH")) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            CErc20 cErc20 = CErc20(address(cToken));
            EIP20Interface underlying = EIP20Interface(cErc20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(cToken));
        }

        return CTokenBalances({
            cToken: address(cToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function cTokenBalancesAll(CToken[] calldata cTokens, address payable account) external returns (CTokenBalances[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenBalances[] memory res = new CTokenBalances[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenBalances(cTokens[i], account);
        }
        return res;
    }

    struct CTokenUnderlyingPrice {
        address cToken;
        uint underlyingPrice;
    }

    function cTokenUnderlyingPrice(CToken cToken) public returns (CTokenUnderlyingPrice memory) {
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
        PriceOracle priceOracle = comptroller.oracle();

        return CTokenUnderlyingPrice({
            cToken: address(cToken),
            underlyingPrice: priceOracle.getUnderlyingPrice(cToken)
        });
    }

    function cTokenUnderlyingPriceAll(CToken[] calldata cTokens) external returns (CTokenUnderlyingPrice[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenUnderlyingPrice[] memory res = new CTokenUnderlyingPrice[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenUnderlyingPrice(cTokens[i]);
        }
        return res;
    }

    struct AccountLimits {
        CToken[] markets;
        uint liquidity;
        uint shortfall;
    }

    function getAccountLimits(ComptrollerLensInterface comptroller, address account) public returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({
            markets: comptroller.getAssetsIn(account),
            liquidity: liquidity,
            shortfall: shortfall
        });
    }

    struct VeeBalanceMetadata {
        uint balance;
    }

    function getVeeBalanceMetadata(Vee vee, address account) external view returns (VeeBalanceMetadata memory) {
        return VeeBalanceMetadata({
            balance: vee.balanceOf(account)
        });
    }

    struct VeeBalanceMetadataExt {
        uint balance;
        uint allocated;
    }

    function getVeeBalanceMetadataExt(Vee vee, ComptrollerLensInterface comptroller, address account) external returns (VeeBalanceMetadataExt memory) {
        uint balance = vee.balanceOf(account);
        comptroller.claimVee(account);
        uint newBalance = vee.balanceOf(account);
        uint accrued = comptroller.veeAccrued(account);
        uint total = add(accrued, newBalance, "sum comp total");
        uint allocated = sub(total, balance, "sub allocated");

        return VeeBalanceMetadataExt({
            balance: balance,
            allocated: allocated
        });
    }

    struct VeeVotes {
        uint blockNumber;
        uint votes;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function add(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }

    function claimVee(address holder,address[] memory comptrollers) external {
        for(uint i = 0; i < comptrollers.length; i++){
            ComptrollerLensInterface comptroller = ComptrollerLensInterface(comptrollers[i]);
            comptroller.claimVee(holder);
        }
    }
}
