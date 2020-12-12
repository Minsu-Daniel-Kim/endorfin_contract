pragma solidity ^0.7.3;

// import "./Shared.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Proposal is ERC20 {
    //Pool token supply
    uint256 public poolTokenSupply;
    uint256 decimal = 10**18;
    //Admin address
    address admin;

    //Proposer address
    address public proposer;

    //Dai token
    IERC20 DAI;

    //Proposal term
    uint256 fundingStartTimestamp;
    uint256 fundingEndTimestamp;
    uint256 optionPrice;
    uint256 optionPremium;
    uint256 optionInterval;
    uint256 commissionRate;
    uint256 period;
    bool isOpen = true;

    // Proposal tokens & maximum amount to fund
    address[] proposalTokens;
    uint256[] maximumAmounts;
    uint256 totalTokenAmount;
    mapping(address => uint256) collectedAmountMap;
    mapping(address => mapping(address => uint256)) public buyerTokenAmount;

    // option buyer
    address[] optionBuyers;
    uint256 collectedProposalTokenAmount;
    mapping(address => uint256) proposalTokenContribution;

    // option seller
    address[] optionSellers;
    uint256 collectedDaiAmount;
    mapping(address => uint256) daiContribution;
    mapping(address => uint256) claimedPoolTokens;

    constructor(
        address _admin,
        address _proposer,
        address[] memory _proposalTokens,
        uint256[] memory _maximumAmounts,
        uint256 _totalTokenAmount,
        string memory _name,
        string memory _symbol
    ) public ERC20(_name, _symbol) {
        admin = _admin;
        proposer = _proposer;
        maximumAmounts = _maximumAmounts;

        poolTokenSupply = 100 * decimal;

        proposalTokens = _proposalTokens;

        totalTokenAmount = _totalTokenAmount;

        // for (uint256 i = 0; i < _proposalTokens.length; i++) {
        //     // proposalTokens.push(IERC20(_proposalTokens[i]));
        //     totalTokenAmount += _maximumAmounts[i];
        // }
    }

    function setTerm(
        uint256 _fundingStartTimestamp,
        uint256 _fundingEndTimestamp,
        uint256 _optionPrice,
        uint256 _optionPremium,
        uint256 _optionInterval,
        uint256 _commissionRate,
        address _daiAddress
    ) public {
        fundingStartTimestamp = _fundingStartTimestamp;
        fundingEndTimestamp = _fundingEndTimestamp;
        optionPrice = _optionPrice;
        optionPremium = _optionPremium;
        optionInterval = _optionInterval;
        commissionRate = _commissionRate;
        DAI = IERC20(_daiAddress);
        period = (commissionRate * decimal * optionInterval) / optionPremium;
    }

    function enterPool(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256 _totalTokenAmount
    ) public {
        require(isOpen, "The pool proposal is already closed");
        require(
            block.timestamp < fundingEndTimestamp,
            "The proposal is already expired"
        );

        require(
            collectedAmountMap[_tokens[0]] + _amounts[0] <= maximumAmounts[0],
            "It's already full..."
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            // IERC20 token = IERC20(_tokens[i]);
            uint256 amount = _amounts[i];
            require(
                ((amount * decimal) / _totalTokenAmount) ==
                    ((maximumAmounts[i] * decimal) / totalTokenAmount),
                "The ratio doesn't match"
            );

            collectedAmountMap[_tokens[i]] += amount;
            buyerTokenAmount[msg.sender][_tokens[i]] = amount;
            // totalTokenCount += amount;
        }

        //Close the pool if it's full
        if (collectedAmountMap[_tokens[0]] >= maximumAmounts[0]) {
            isOpen = false;
        }

        collectedProposalTokenAmount += _amounts[0];
        proposalTokenContribution[msg.sender] = _amounts[0];

        optionBuyers.push(msg.sender);
    }

    function sellOption(uint256 daiAmount) public {
        require(!isOpen, "Wait until funding phase is finished");
        require(DAI.balanceOf(msg.sender) >= daiAmount, "Lack of DAI balance");

        require(
            collectedDaiAmount + daiAmount <= optionPrice,
            "It's already full"
        );

        collectedDaiAmount += daiAmount;
        daiContribution[msg.sender] = daiAmount;
        optionSellers.push(msg.sender);
    }

    function finalizePool() public {
        require(
            msg.sender == proposer || msg.sender == admin,
            "Only proposer can close the open proposal"
        );

        for (uint256 i = 0; i < optionBuyers.length; i++) {
            for (uint256 j = 0; j < proposalTokens.length; j++) {
                IERC20 token = IERC20(proposalTokens[j]);


                    uint256 amount
                 = buyerTokenAmount[optionBuyers[i]][proposalTokens[j]];
                token.transferFrom(optionBuyers[i], address(this), amount);
                // token.approve(address(this), amount);
            }

            uint256 poolTokenAmount = (
                ((poolTokenSupply - (commissionRate * decimal)) *
                    proposalTokenContribution[optionBuyers[i]])
            ) / collectedProposalTokenAmount;

            _mint(optionBuyers[i], poolTokenAmount);
        }

        for (uint256 i = 0; i < optionSellers.length; i++) {
            uint256 daiAmount = daiContribution[optionSellers[i]];
            DAI.transferFrom(optionSellers[i], address(this), daiAmount);
            // DAI.approve(address(this), daiAmount);
        }

        isOpen = false;
    }

    function claimPremium() public {
        require(daiContribution[msg.sender] > 0);

        // days -> unixtimestamps
        uint256 optionIntervalUnixtimestamp = optionInterval * 60 * 60 * 24;

        // elapse time in unixtimestamps
        uint256 diff = block.timestamp - fundingEndTimestamp;

        // N possible claims
        uint256 mult = diff / optionIntervalUnixtimestamp;

        // Total possible claim amounts
        uint256 premium = (mult * optionPremium * daiContribution[msg.sender]) /
            optionPrice;

        // Eligible claim amount
        uint256 eligibleClaimAmount = premium - claimedPoolTokens[msg.sender];

        require(eligibleClaimAmount > 0, "Nothing to claim");

        // Claim the eligible amount
        _mint(msg.sender, eligibleClaimAmount);
        // DAI.transfer(msg.sender, eligibleClaimAmount);

        claimedPoolTokens[msg.sender] += eligibleClaimAmount;
    }

    event Refund(uint256 amount);

    function refund() public {
        require(
            msg.sender == admin,
            "Only admin can liquidate the open proposal"
        );
        for (uint256 i = 0; i < optionBuyers.length; i++) {
            for (uint256 j = 0; j < proposalTokens.length; j++) {
                IERC20 token = IERC20(proposalTokens[j]);
                uint256 amount = (collectedAmountMap[proposalTokens[j]] *
                    this.balanceOf(optionBuyers[i])) / this.totalSupply();
                emit Refund(amount);
                token.transfer(optionBuyers[i], amount);
            }

            _burn(optionBuyers[i], this.balanceOf(optionBuyers[i]));
        }

        for (uint256 i = 0; i < optionSellers.length; i++) {
            for (uint256 j = 0; j < proposalTokens.length; j++) {
                IERC20 token = IERC20(proposalTokens[j]);
                uint256 amount = (collectedAmountMap[proposalTokens[j]] *
                    this.balanceOf(optionSellers[i])) / this.totalSupply();

                token.transfer(optionSellers[i], amount);
            }
            uint256 daiAmount = daiContribution[optionSellers[i]];
            DAI.transfer(optionSellers[i], daiAmount);
            _burn(optionSellers[i], this.balanceOf(optionSellers[i]));
        }

        isOpen = false;
    }

    function exerciseOption() public {
        require(msg.sender == admin, "Only admin can exercise option");

        for (uint256 i = 0; i < optionBuyers.length; i++) {
            DAI.transfer(
                optionBuyers[i],
                (collectedDaiAmount *
                    proposalTokenContribution[optionBuyers[i]]) /
                    collectedProposalTokenAmount
            );
            _burn(optionBuyers[i], this.balanceOf(optionBuyers[i]));
        }

        for (uint256 i = 0; i < optionSellers.length; i++) {
            for (uint256 j = 0; j < proposalTokens.length; j++) {
                IERC20 token = IERC20(proposalTokens[j]);
                uint256 amount = ((collectedAmountMap[proposalTokens[j]] *
                    daiContribution[optionSellers[i]]) / collectedDaiAmount);
                token.transfer(optionSellers[i], amount);
            }
            _burn(optionSellers[i], this.balanceOf(optionSellers[i]));
        }
    }

    function isPeriodEnded() public view returns (bool) {
        return block.timestamp > fundingEndTimestamp + (period * 3600 * 24);
    }

    function getProposer() public view returns (address) {
        return proposer;
    }

    function getOptionBuyers() public view returns (address[] memory) {
        return optionBuyers;
    }

    function getOptionSellers() public view returns (address[] memory) {
        return optionSellers;
    }

    function getFundingStartTimestamp() public view returns (uint256) {
        return fundingStartTimestamp;
    }

    function getFundingEndTimestamp() public view returns (uint256) {
        return fundingEndTimestamp;
    }

    function getOptionPrice() public view returns (uint256) {
        return optionPrice;
    }

    function getTotalTokenAmount() public view returns (uint256) {
        return totalTokenAmount;
    }

    function getOptionPremium() public view returns (uint256) {
        return optionPremium;
    }

    function getOptionInterval() public view returns (uint256) {
        return optionInterval;
    }

    function getIsOpen() public view returns (bool) {
        return isOpen;
    }

    function getProposalTokens() public view returns (address[] memory) {
        return proposalTokens;
    }

    function getMaximumAmounts() public view returns (uint256[] memory) {
        return maximumAmounts;
    }
}
