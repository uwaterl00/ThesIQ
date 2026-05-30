import { expect } from "chai";
import { ethers } from "hardhat";

describe("ThesIQ Token", function () {
  let thesIQ: any;
  let owner: any;
  let minter: any;
  let burner: any;
  let addr1: any;

  beforeEach(async function () {
    [owner, minter, burner, addr1] = await ethers.getSigners();
    
    const ThesIQ = await ethers.getContractFactory("ThesIQ");
    thesIQ = await ThesIQ.deploy(owner.address);
    await thesIQ.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await thesIQ.owner()).to.equal(owner.address);
    });

    it("Should set initial minter and burner to owner", async function () {
      expect(await thesIQ.isMinter(owner.address)).to.be.true;
      expect(await thesIQ.isBurner(owner.address)).to.be.true;
    });

    it("Should have correct token name and symbol", async function () {
      expect(await thesIQ.name()).to.equal("ThesIQ");
      expect(await thesIQ.symbol()).to.equal("IQ");
    });
  });

  describe("Minting", function () {
    it("Should allow minter to mint tokens", async function () {
      const mintAmount = ethers.parseEther("1000");
      await thesIQ.mint(addr1.address, mintAmount);
      expect(await thesIQ.balanceOf(addr1.address)).to.equal(mintAmount);
    });

    it("Should not allow non-minter to mint", async function () {
      const mintAmount = ethers.parseEther("1000");
      await expect(
        thesIQ.connect(addr1).mint(addr1.address, mintAmount)
      ).to.be.revertedWith("ThesIQ: caller is not a minter");
    });

    it("Should not exceed max supply", async function () {
      const maxSupply = ethers.parseEther("1000000000");
      const overAmount = ethers.parseEther("1000000001");
      await expect(
        thesIQ.mint(addr1.address, overAmount)
      ).to.be.revertedWith("ThesIQ: exceeds max supply");
    });

    it("Should not mint to zero address", async function () {
      const mintAmount = ethers.parseEther("1000");
      await expect(
        thesIQ.mint(ethers.ZeroAddress, mintAmount)
      ).to.be.revertedWith("ThesIQ: cannot mint to zero address");
    });
  });

  describe("Minter Management", function () {
    it("Should add minter", async function () {
      await thesIQ.addMinter(minter.address);
      expect(await thesIQ.isMinter(minter.address)).to.be.true;
    });

    it("Should remove minter", async function () {
      await thesIQ.addMinter(minter.address);
      await thesIQ.removeMinter(minter.address);
      expect(await thesIQ.isMinter(minter.address)).to.be.false;
    });

    it("Should not allow non-owner to add minter", async function () {
      await expect(
        thesIQ.connect(addr1).addMinter(minter.address)
      ).to.be.revertedWithCustomError(thesIQ, "OwnableUnauthorizedAccount");
    });
  });

  describe("Burning", function () {
    it("Should allow burner to burn tokens", async function () {
      const mintAmount = ethers.parseEther("1000");
      await thesIQ.mint(owner.address, mintAmount);
      await thesIQ.burn(ethers.parseEther("100"));
      expect(await thesIQ.balanceOf(owner.address)).to.equal(ethers.parseEther("900"));
    });

    it("Should not allow non-burner to burn", async function () {
      const mintAmount = ethers.parseEther("1000");
      await thesIQ.mint(addr1.address, mintAmount);
      await expect(
        thesIQ.connect(addr1).burn(ethers.parseEther("100"))
      ).to.be.revertedWith("ThesIQ: caller is not a burner");
    });
  });
});