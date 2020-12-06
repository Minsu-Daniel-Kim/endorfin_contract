pragma solidity ^0.7.3;

// import 'Token.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Proposal {
    address admin;
    IERC20 DAI;

    // Proposal spec
    address[] tokenAddresses;
    IERC20[] tokens;
    address public proposer;
    address[] participants;
    uint256 nParticipant;
    uint256 poolPeriod;
    uint256[] amounts;
    uint256 startDate;
    uint256 endDate;
    uint256 period;
    uint256 optionPrice;
    uint256 optionPremium;
    uint256 optionInterval;
    bool isOpen = true;

    // option buyer list
    address[] optionBuyers;

    //
    struct Pair {
        IERC20 token;
        uint256 amount;
    }

    // Maximum amount of each token to enter
    mapping(IERC20 => uint256) maxAmountMap;

    // Amount of each token collected
    mapping(IERC20 => uint256) collectedAmountMap;

    // participate - token
    mapping(address => Pair[]) tokenMap;

    // participate - amount commited
    mapping(address => uint256) amountMap;

    // Total amount of dai reserved
    uint256 optionBuyerTotalAmmount;

    // Option buyer - Dai amount
    // mapping(address => uint256) optionBuyerMap;

    // Option buyer - Dai commit ratio
    mapping(address => uint256) optionBuyerPortionMap;

    // option buyer - claimed amount
    mapping(address => uint256) claimedDai;

    constructor(
        address _admin,
        address _proposer,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _period,
        uint256 _optionPrice,
        uint256 _optionPremium,
        uint256 _optionInterval,
        uint256 _poolPeriod
    ) public {
        admin = _admin;
        proposer = _proposer;
        tokenAddresses = _tokens;
        amounts = _amounts;
        startDate = _startDate;
        endDate = _endDate;
        period = _period;
        optionPrice = _optionPrice;
        optionPremium = _optionPremium;
        optionInterval = _optionInterval;
        poolPeriod = _poolPeriod;

        for (uint256 i = 0; i < _tokens.length; i++) {
            tokens.push(IERC20(_tokens[i]));
            maxAmountMap[IERC20(_tokens[i])] = _amounts[i];
        }
    }

    function setDaiAddress(address daiAddress) public {
        DAI = IERC20(daiAddress);
    }

    function enterPool(address[] memory _tokens, uint256[] memory _amounts)
        public
    {
        require(isOpen, "The pool proposal is already closed");
        require(block.timestamp < endDate, "The proposal is already expired");

        require(
            collectedAmountMap[tokens[0]] < maxAmountMap[tokens[0]],
            "It's already full"
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20 token = IERC20(_tokens[i]);
            uint256 amount = _amounts[i];
            token.approve(address(this), amount);

            tokenMap[msg.sender].push(Pair({token: token, amount: amount}));

            collectedAmountMap[token] += amount;
        }

        //Close the pool if it's full
        if (collectedAmountMap[tokens[0]] >= amounts[0]) {
            isOpen = false;
        }

        participants.push(msg.sender);
        nParticipant++;
    }

    // function getAllowance() external view returns (uint256) {

    // }

    function finalizePool() public {
        require(
            msg.sender == proposer || msg.sender == admin,
            "Only proposer can close the open proposal"
        );

        for (uint256 i = 0; i < participants.length; i++) {
            // IERC20 token = tokenMap[participants[i]];

            Pair[] storage pairs = tokenMap[participants[i]];

            for (uint256 j = 0; j < pairs.length; j++) {
                IERC20 token = pairs[j].token;
                uint256 amount = pairs[j].amount;
                token.transferFrom(participants[i], address(this), amount);
            }
        }

        isOpen = false;
    }

    function buyOption() public {
        require(
            DAI.balanceOf(msg.sender) >= optionPrice,
            "Lack of DAI balance"
        );

        DAI.transferFrom(msg.sender, address(this), optionPrice);

        optionBuyerTotalAmmount += optionPrice;

        optionBuyerPortionMap[msg.sender] =
            optionPrice /
            optionBuyerTotalAmmount;

        optionBuyers.push(msg.sender);
    }

    function claimPremium() public {
        require(optionBuyerPortionMap[msg.sender] > 0);

        // days -> unixtimestamps
        uint256 optionIntervalUnixtimestamp = optionInterval * 60 * 60 * 24;

        // elapse time in unixtimestamps
        uint256 diff = block.timestamp - endDate;

        // N possible claims
        uint256 mult = diff / optionIntervalUnixtimestamp;

        // Total possible claim amounts
        uint256 premium = mult *
            optionPremium *
            optionBuyerPortionMap[msg.sender];

        // Eligible claim amount
        uint256 eligibleClaimAmount = premium - claimedDai[msg.sender];

        require(eligibleClaimAmount > 0, "Nothing to claim");

        // Claim the eligible amount
        DAI.transfer(msg.sender, eligibleClaimAmount);

        claimedDai[msg.sender] += eligibleClaimAmount;
    }

    function liquidatePool() public {
        require(
            msg.sender == admin,
            "Only admin can liquidate the open proposal"
        );
        for (uint256 i = 0; i < participants.length; i++) {
            Pair[] storage pairs = tokenMap[participants[i]];

            for (uint256 j = 0; j < pairs.length; j++) {
                IERC20 token = pairs[j].token;
                uint256 amount = pairs[j].amount;
                token.transfer(participants[i], amount);
            }
        }

        isOpen = false;
    }

    function getTokens() public view returns (address[] memory) {
        return tokenAddresses;
    }

    function getProposer() public view returns (address) {
        return proposer;
    }

    function getParticipants() public view returns (address[] memory) {
        return participants;
    }

    function getPeriod() public view returns (uint256) {
        return period;
    }

    function getOptionPrice() public view returns (uint256) {
        return optionPrice;
    }

    function getOptionPremium() public view returns (uint256) {
        return optionPremium;
    }

    function getPoolPeriod() public view returns (uint256) {
        return poolPeriod;
    }

    function getOptionInterval() public view returns (uint256) {
        return optionInterval;
    }

    function getStartDate() public view returns (uint256) {
        return startDate;
    }

    function getEndDate() public view returns (uint256) {
        return endDate;
    }

    function getIsOpen() public view returns (bool) {
        return isOpen;
    }

    function getAmounts() public view returns (uint256[] memory) {
        return amounts;
    }

    // uint256 startDate;
    // uint256 endDate;
}
