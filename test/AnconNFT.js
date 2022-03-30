const { expect } = require("chai");
const { ethers } = require("hardhat");
require("@nomiclabs/hardhat-web3");
require("dotenv").config();
const AnconNFTjson = require("../artifacts/contracts/AnconNFT.sol/AnconNFT.json");

describe("AnconNFT contract", function () {
  let token,
    Token,
    owner,
    addr1,
    addr2,
    addr3,
    addr4,
    AnconToken,
    anconToken,
    web3NFTContract,
    transferEventLog,
    addMintInfoEventLogs;

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

    web3NFTContract = new web3.eth.Contract(AnconNFTjson.abi, anconNFT.address);

    //Mint Query 'Transfer' event
    transferEventLog = await web3NFTContract.getPastEvents("Transfer", {
      toBlock: "latest",
      fromBlock: 0,
    });

    //Mint Query 'AddMintInfo' event
    addMintInfoEventLogs = await web3NFTContract.getPastEvents("AddMintInfo", {
      toBlock: "latest",
      fromBlock: 0,
    });
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

  describe("Service fee for contract", function () {
    it("should get & set service fee for contract and attempt to discount it from the nft minter address", async function () {
      await anconNFT.setServiceFeeForContract(1);

      await expect(
        anconNFT.mint(
          addr4.address,
          "203b6379-cb5a-4b82-8267-c096f540e48b",
          100
        )
      ).to.be.revertedWith(
        "VM Exception while processing transaction: reverted with reason string 'ERC20: transfer amount exceeds allowance'"
      );
    });
  });

  describe("Verify 'Transfer' events", function () {
    it("Should have the corresponding 'from' field value", async function () {
      expect(transferEventLog.length).to.equal(5);

      //Check mint 'from'
      expect(transferEventLog[0].returnValues.from).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(transferEventLog[1].returnValues.from).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(transferEventLog[2].returnValues.from).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(transferEventLog[3].returnValues.from).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(transferEventLog[4].returnValues.from).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });

    it("Should have the corresponding 'to' field value", async function () {
      //Check mint 'to'
      expect(transferEventLog[0].returnValues.to).to.equal(owner.address);
      expect(transferEventLog[1].returnValues.to).to.equal(addr1.address);
      expect(transferEventLog[2].returnValues.to).to.equal(addr1.address);
      expect(transferEventLog[3].returnValues.to).to.equal(addr2.address);
      expect(transferEventLog[4].returnValues.to).to.equal(addr4.address);
    });

    it("Should have the corresponding 'tokenId' field value", async function () {
      //Check mint 'tokenId'
      expect(transferEventLog[0].returnValues.tokenId).to.equal("1");
      expect(transferEventLog[1].returnValues.tokenId).to.equal("2");
      expect(transferEventLog[2].returnValues.tokenId).to.equal("3");
      expect(transferEventLog[3].returnValues.tokenId).to.equal("4");
      expect(transferEventLog[4].returnValues.tokenId).to.equal("5");
    });
  });

  describe("Verify 'AddMintInfo' events", function () {
    it("Should have the corresponding 'creator' field value", async () => {
      expect(addMintInfoEventLogs.length).to.equal(5);

      expect(addMintInfoEventLogs[0].returnValues.creator).to.equal(
        owner.address
      );
      expect(addMintInfoEventLogs[1].returnValues.creator).to.equal(
        addr1.address
      );
      expect(addMintInfoEventLogs[2].returnValues.creator).to.equal(
        addr1.address
      );
      expect(addMintInfoEventLogs[3].returnValues.creator).to.equal(
        addr2.address
      );
      expect(addMintInfoEventLogs[4].returnValues.creator).to.equal(
        addr4.address
      );
    });

    it("Should have the corresponding 'uri' field value", async () => {
      expect(addMintInfoEventLogs[0].returnValues.uri).to.equal(
        "d0ae3a5b-b86d-4227-9bec-e2438ab485ca"
      );
      expect(addMintInfoEventLogs[1].returnValues.uri).to.equal(
        "a67083c3-a36b-4956-baa0-c9239c75c582"
      );
      expect(addMintInfoEventLogs[2].returnValues.uri).to.equal(
        "04030310-d8df-441a-89f6-44ab9c7dab19"
      );
      expect(addMintInfoEventLogs[3].returnValues.uri).to.equal(
        "f9754447-70e3-440e-90a5-86e632dbb4c2"
      );
      expect(addMintInfoEventLogs[4].returnValues.uri).to.equal(
        "866124d8-6c7b-4d50-8705-f7dea72e4695"
      );
    });

    it("Should have the corresponding 'tokenId' field value", async () => {
      expect(addMintInfoEventLogs[0].returnValues.tokenId).to.equal("1");
      expect(addMintInfoEventLogs[1].returnValues.tokenId).to.equal("2");
      expect(addMintInfoEventLogs[2].returnValues.tokenId).to.equal("3");
      expect(addMintInfoEventLogs[3].returnValues.tokenId).to.equal("4");
      expect(addMintInfoEventLogs[4].returnValues.tokenId).to.equal("5");
    });

    it("Should have the corresponding 'royaltyFee' field value", async () => {
      expect(addMintInfoEventLogs[0].returnValues.royaltyFee).to.equal("1");
      expect(addMintInfoEventLogs[1].returnValues.royaltyFee).to.equal("2");
      expect(addMintInfoEventLogs[2].returnValues.royaltyFee).to.equal("20");
      expect(addMintInfoEventLogs[3].returnValues.royaltyFee).to.equal("100");
      expect(addMintInfoEventLogs[4].returnValues.royaltyFee).to.equal("10000");
    });
  });
});
