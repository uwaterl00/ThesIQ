import { expect } from "chai";
import { ethers } from "hardhat";

describe("ThesIQVotes Token", function () {
  let thesIQVotes: any;
  let owner: any;
  let minter: any;
  let addr1: any;
  let addr2: any;

  beforeEach(async function () {
    [owner, minter, addr1, addr2] = await ethers.getSigners();
    
    const ThesIQVotes = await ethers.getContractFactory("ThesIQVotes");
    thesIQVotes = await ThesIQVotes.deploy(owner.address);
    await thesIQVotes.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await thesIQVotes.owner()).to.equal(owner.address);
    });

    it("Should have correct token name and symbol", async function () {
      expect(await thesIQVotes.name()).to.equal("ThesIQ Votes");
      expect(await thesIQVotes.symbol()).to.equal("vIQ");
    });
  });

  describe("Minting and Voting", function () {
    it("Should mint tokens and update voting power", async function () {
      const mintAmount = ethers.parseEther("1000");
      await thesIQVotes.mint(addr1.address, mintAmount);
      expect(await thesIQVotes.balanceOf(addr1.address)).to.equal(mintAmount);
    });

    it("Should allow delegation of votes", async function () {
      const mintAmount = ethers.parseEther("1000");
      await thesIQVotes.mint(addr1.address, mintAmount);
      await thesIQVotes.connect(addr1).delegate(addr1.address);
      expect(await thesIQVotes.getVotes(addr1.address)).to.equal(mintAmount);
    });

    it("Should track voting checkpoints", async function () {
      const mintAmount = ethers.parseEther("1000");
      await thesIQVotes.mint(addr1.address, mintAmount);
      await thesIQVotes.connect(addr1).delegate(addr1.address);
      
      const blockNumber = await ethers.provider.getBlockNumber();
      const votes = await thesIQVotes.getPastVotes(addr1.address, blockNumber - 1);
      expect(votes).to.equal(0);
    });
  });

  describe("Minter Management", function () {
    it("Should add minter", async function () {
      await thesIQVotes.addMinter(minter.address);
      expect(await thesIQVotes.isMinter(minter.address)).to.be.true;
    });

    it("Should allow new minter to mint", async function () {
      await thesIQVotes.addMinter(minter.address);
      const mintAmount = ethers.parseEther("500");
      await thesIQVotes.connect(minter).mint(addr2.address, mintAmount);
      expect(await thesIQVotes.balanceOf(addr2.address)).to.equal(mintAmount);
    });
  });
});