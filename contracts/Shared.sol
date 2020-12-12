pragma solidity ^0.7.3;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import "./Proposal.sol";

contract Shared {
    // uint256 poolPeriod;
    uint256 public poolTokenSupply;
    address admin;
    IERC20 DAI;

    // Proposal spec
    // address[] tokenAddresses;
    IERC20[] tokens;
    address public proposer;
    uint256[] amounts;
    uint256 startDate;
    uint256 endDate;
    uint256 period;
    uint256 optionPrice;
    uint256 optionPremium;
    uint256 optionInterval;
    uint256 commission;
    bool isOpen = true;

    // option buyer list
    address[] optionSellers;
    address[] optionBuyers;
    mapping(IERC20 => uint256) collectedAmountMap;

    uint256 optionSellerTotalAmmount;

    // Option buyer - Dai commit ratio
    mapping(address => uint256) optionSellerPortionMap;

    uint256 optionBuyerTotalAmmount;

    // Option buyer - Dai commit ratio
    mapping(address => uint256) optionBuyerPortionMap;

    // option buyer - claimed amount
    mapping(address => uint256) claimedPoolTokens;
}
