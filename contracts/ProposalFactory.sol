pragma solidity ^0.7.3;

import "./Proposal.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.1.0/contracts/token/ERC20/IERC20.sol";

// Proposal factory creates a new pool proposal by pool proposer
contract ProposalFactory {
    address[] public deployedProposals;

    function createProposal(
        address _admin,
        address _proposer,
        address[] memory _proposalTokens,
        uint256[] memory _maximumAmounts,
        uint256 _totalTokenAmount,
        uint256 _fundingStartTimestamp,
        uint256 _fundingEndTimestamp,
        uint256 _optionPrice,
        uint256 _optionPremium,
        uint256 _optionInterval,
        uint256 _commission,
        string memory _name,
        string memory _symbol,
        address _daiAddress
    ) public {
        Proposal newProposal = new Proposal(
            _admin,
            _proposer,
            _proposalTokens,
            _maximumAmounts,
            _totalTokenAmount,
            _name,
            _symbol
        );
        newProposal.setTerm(
            _fundingStartTimestamp,
            _fundingEndTimestamp,
            _optionPrice,
            _optionPremium,
            _optionInterval,
            _commission,
            _daiAddress
        );
        deployedProposals.push(address(newProposal));
    }

    function getDeployedProposals() public view returns (address[] memory) {
        return deployedProposals;
    }
}
