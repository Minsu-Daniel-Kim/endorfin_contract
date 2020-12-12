const { time } = require("@openzeppelin/test-helpers");

const ERC20 = artifacts.require("DAI.sol");
const Proposal = artifacts.require("Proposal.sol");
const ProposalFactory = artifacts.require("ProposalFactory.sol");

const INITIAL_AMOUNT = web3.utils.toWei("100");

contract("RFT", async (addresses) => {
  const [
    admin,
    optionBuyer1,
    optionBuyer2,
    optionSeller1,
    optionSeller2,
    _,
  ] = addresses;

  let dai = null;
  let link = null;
  let aave = null;

  let proposalFactory = null;
  let deployedProposals = null;
  let proposal_1 = null;

  const getUserBalance = () => {
    [dai, link, aave].forEach((token) => {
      [optionBuyer1, optionBuyer2, optionSeller1, optionSeller2].forEach(
        async (user) => {
          const balance = await token.balanceOf(user);
          console.log(user + " " + token + " - ", balance.toString());
        }
      );
    });
  };
  const getContractBalance = () => {
    [dai, link, aave].forEach(async (token) => {
      const balance = await token.balanceOf(proposal_1.address);
      console.log("Proposal contract " + token + " - ", balance.toString());
    });
  };

  it("creates three tokens: DAI, LINK, AAVE", async () => {
    dai = await ERC20.new("DAI Stablecoin", "DAI");
    link = await ERC20.new("Chainlink", "LINK");
    aave = await ERC20.new("Aave", "AAVE");

    console.log("DAI address: ", dai.address);
    console.log("link address: ", link.address);
    console.log("aave address: ", aave.address);
  });

  it("allocates tokens to users", async () => {
    await Promise.all([
      dai.mint(optionBuyer1, INITIAL_AMOUNT),
      link.mint(optionBuyer1, INITIAL_AMOUNT),
      aave.mint(optionBuyer1, INITIAL_AMOUNT),

      dai.mint(optionBuyer2, INITIAL_AMOUNT),
      link.mint(optionBuyer2, INITIAL_AMOUNT),
      aave.mint(optionBuyer2, INITIAL_AMOUNT),

      dai.mint(optionSeller1, INITIAL_AMOUNT),
      link.mint(optionSeller1, INITIAL_AMOUNT),
      aave.mint(optionSeller1, INITIAL_AMOUNT),

      dai.mint(optionSeller2, INITIAL_AMOUNT),
      link.mint(optionSeller2, INITIAL_AMOUNT),
      aave.mint(optionSeller2, INITIAL_AMOUNT),
    ]);

    getUserBalance();
  });

  it("allocates tokens to users", async () => {
    proposalFactory = await ProposalFactory.new();
    console.log("Proposal factory address: ", proposalFactory.address);
  });

  it("creates a proposal", async () => {
    const startDate = new Date("2020-12-05").getTime();
    console.log(startDate);

    const endDate = new Date("2020-12-07").getTime();
    console.log(endDate);

    const [aaveAmount, linkAmount] = [10, 20];

    await proposalFactory.createProposal(
      admin, // _admin
      admin, // _proposer
      [aave.address, link.address], // _proposalTokens
      [
        web3.utils.toWei(aaveAmount.toString()),
        web3.utils.toWei(linkAmount.toString()),
      ], // _maximumAmounts
      web3.utils.toWei((aaveAmount + linkAmount).toString()),
      startDate, // _fundingStartTimestamp
      endDate, // _fundingEndTimestamp
      web3.utils.toWei("100"), // _optionPrice
      web3.utils.toWei("1"), // _optionPremium
      7, // _optionInterval
      30, // _commission
      "wow", // _name
      "WOW", // _symbol
      dai.address
    );

    deployedProposals = await proposalFactory.getDeployedProposals();
    console.log("deployedProposals: ", deployedProposals);
  });

  it("shows a 1st proposal description", async () => {
    proposal_1 = await Proposal.at(deployedProposals[0]);
  });

  it("User 1 enters a pool", async () => {
    let optionBuyers = await proposal_1.getOptionBuyers();

    console.log("Option buyers before: ", optionBuyers.toString());

    const [aaveAmount1, linkAmount1] = [6, 12];
    await aave.approve(
      proposal_1.address,
      web3.utils.toWei(aaveAmount1.toString()),
      {
        from: optionBuyer1,
      }
    );
    await link.approve(
      proposal_1.address,
      web3.utils.toWei(linkAmount1.toString()),
      {
        from: optionBuyer1,
      }
    );
    await proposal_1.enterPool(
      [aave.address, link.address],
      [
        web3.utils.toWei(aaveAmount1.toString()),
        web3.utils.toWei(linkAmount1.toString()),
      ],
      web3.utils.toWei((aaveAmount1 + linkAmount1).toString()),
      { from: optionBuyer1 }
    );

    const [aaveAmount2, linkAmount2] = [4, 8];
    await aave.approve(
      proposal_1.address,
      web3.utils.toWei(aaveAmount2.toString()),
      {
        from: optionBuyer2,
      }
    );
    await link.approve(
      proposal_1.address,
      web3.utils.toWei(linkAmount2.toString()),
      {
        from: optionBuyer2,
      }
    );

    await proposal_1.enterPool(
      [aave.address, link.address],
      [
        web3.utils.toWei(aaveAmount2.toString()),
        web3.utils.toWei(linkAmount2.toString()),
      ],
      web3.utils.toWei((aaveAmount2 + linkAmount2).toString()),
      { from: optionBuyer2 }
    );
    optionBuyers = await proposal_1.getOptionBuyers();

    console.log("Option buyers after: ", optionBuyers.toString());
    const contractDaiBalance = await dai.balanceOf(proposal_1.address);
    const contractLinkBalance = await link.balanceOf(proposal_1.address);
    const contractAaveBalance = await aave.balanceOf(proposal_1.address);

    console.log("contractDaiBalance - DAI ", contractDaiBalance.toString());
    console.log("contractLinkBalance - LINK ", contractLinkBalance.toString());
    console.log("contractAaveBalance - AAVE ", contractAaveBalance.toString());
  });

  it("sells an option", async () => {
    await dai.approve(proposal_1.address, web3.utils.toWei("20"), {
      from: optionSeller1,
    });
    await proposal_1.sellOption(web3.utils.toWei("20"), {
      from: optionSeller1,
    });
    const daiBalanceOptionSeller1 = await dai.balanceOf(optionSeller1);
    console.log(
      "daiBalanceOptionSeller1: ",
      daiBalanceOptionSeller1.toString()
    );
  });

  it("finalizes a pool", async () => {
    await proposal_1.finalizePool({
      from: admin,
    });

    const link_balance = await proposal_1.buyerTokenAmount(
      optionBuyer1,
      link.address
    );
    console.log("link_balance: ", link_balance.toString());
    const aave_balance = await proposal_1.buyerTokenAmount(
      optionBuyer1,
      aave.address
    );
    console.log("aave_balance: ", aave_balance.toString());

    const poolToken = await proposal_1.balanceOf(optionBuyer1);
    console.log("poolToken: ", poolToken.toString());

    getUserBalance();
    getContractBalance();
  });

  it("exercises an option", async () => {
    await proposal_1.exerciseOption({ from: admin });
    getUserBalance();
    getContractBalance();
  });

  // it("refunds", async () => {
  //   await proposal_1.refund({ from: admin });
  //   getUserBalance();
  //   getContractBalance();
  // });
});
