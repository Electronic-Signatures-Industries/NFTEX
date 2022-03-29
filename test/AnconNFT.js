const { expect } = require("chai");
const { ethers } = require("hardhat");
require("@nomiclabs/hardhat-web3");
require("dotenv").config();
const AnconNFTjson = require("../artifacts/contracts/AnconNFT.sol/AnconNFT.json");

describe("NFTEX contract", function () {
    let token,
    Token,
    owner,
    addr1,
    addr2,
    addr3,
    addr4,
    AnconToken,
    anconToken;

  before(async function () {
    // Token = await ethers.getContractFactory("Token");
    AnconNFT = await ethers.getContractFactory("AnconNFT");
    AnconToken = await ethers.getContractFactory("ANCON");

    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    anconToken = await AnconToken.connect(owner).deploy();
  });

  beforeEach(async function () {
    anconToken = await AnconToken.connect(owner).deploy();
    anconNFT = await AnconNFT.connect(owner).deploy(
      "AnconTest",
      "AT",
      anconToken.address,
      "0x8626f6940e2eb28930efb4cef49b2d1f2c9c1199"
    );

    await anconNFT.mint(
      owner.address,
      "d0ae3a5b-b86d-4227-9bec-e2438ab485ca", //UUID as uri
      1 //royalty fee percent from 0 to 10000, 1 = 0.01%, 10000 = 100.00%
    );
    await anconNFT.mint(
      addr1.address,
      "a67083c3-a36b-4956-baa0-c9239c75c582",
      2
    );
    await anconNFT.mint(
      addr1.address,
      "04030310-d8df-441a-89f6-44ab9c7dab19",
      20
    );
    await anconNFT.mint(
      addr2.address,
      "f9754447-70e3-440e-90a5-86e632dbb4c2",
      100
    );

    await anconNFT.mint(
      addr4.address,
      "866124d8-6c7b-4d50-8705-f7dea72e4695",
      10000
    );
  });

  //setServiceFeeForContract

  describe("Deployment", function () {
    it("Should check token balances", async function () {
      const ownerBalance = await anconNFT.balanceOf(owner.address);
      const addr1Balance = await anconNFT.balanceOf(addr1.address);
      const addr2Balance = await anconNFT.balanceOf(addr2.address);
      const addr3Balance = await anconNFT.balanceOf(addr3.address);

      const addr4AnconNFTBalance = await anconNFT.balanceOf(addr4.address);
      const addr4AnconTokenBalance = await anconToken.balanceOf(addr4.address);

      expect(ownerBalance).to.equal(1);
      expect(addr1Balance).to.equal(2);
      expect(addr2Balance).to.equal(1);
      expect(addr3Balance).to.equal(0);

      expect(addr4AnconNFTBalance).to.equal(1);
      // expect(ownerAnconTokenBalance).to.equal(100);
    });
  });

  // describe("Service fee for contract", function () {
  //   it("should get & set service five fee for contract and discount it from the nft minter address", async function () {
      
  //   });
  // });

  describe("Get at mint events", function () {
    it("Should print event logs", async function () {
      const web3NFTContract = new web3.eth.Contract(
        AnconNFTjson.abi,
        anconNFT.address
      );

      //Mint Query event
      const transferEventLog = await web3NFTContract.getPastEvents("Transfer", {
        toBlock: "latest",
        fromBlock: 0,
        filter: { user: owner.address },
      });

      const setOnchainEventLog = await web3NFTContract.getPastEvents(
        "AddMintInfo",
        {
          toBlock: "latest",
          fromBlock: 0,
          filter: { user: owner.address },
        }
      );

      const setOnchainEventLogAll = await web3NFTContract.getPastEvents(
        "AddMintInfo",
        {
          toBlock: "latest",
          fromBlock: 0,
        }
      );

      console.log(
        "\n 'Transfer' Get past events Web3 response print",
        transferEventLog[0]
      );

      console.log(
        "\n 'AddMintInfo' from owner Get past events Web3 response print",
        setOnchainEventLog
      );

      console.log(
        "\n 'AddMintInfo' all Get past events Web3 response print",
        setOnchainEventLogAll
      );
    });
  });

});
