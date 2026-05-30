import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("ThesIQStaking", function () {
  let staking: any;
  let stakingToken: any;
  let rewardToken: any;
  let owner: any;
  let user1: any;
  let user2: any;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const ERC20 = await ethers.getContractFactory("ThesIQ");
    stakingToken = await ERC20.deploy(owner.address);
    await stakingToken.deployed();

    rewardToken = await ERC20.deploy(owner.address);
    await rewardToken.deployed();

    const Staking = await ethers.getContractFactory("ThesIQStaking");
    staking = await Staking.deploy(owner.address, stakingToken.address, rewardToken.address);
    await staking.deployed();

    await stakingToken.addMinter(owner.address);
    await rewardToken.addMinter(staking.address);

    const stakeAmount = ethers.parseEther("1000");
    await stakingToken.mint(user1.address, stakeAmount);
    await stakingToken.mint(user2.address, stakeAmount);
    await rewardToken.mint(staking.address, ethers.parseEther("1000000"));
  });

  describe("Staking", function () {
    it("Should allow user to stake tokens", async function () {
      const stakeAmount = ethers.parseEther("100");
      await stakingToken.connect(user1).approve(staking.address, stakeAmount);
      await staking.connect(user1).stake(stakeAmount);

      const [amount] = await staking.getStakeInfo(user1.address);
      expect(amount).to.equal(stakeAmount);
    });

    it("Should track total staked amount", async function () {
      const stakeAmount = ethers.parseEther("100");
      await stakingToken.connect(user1).approve(staking.address, stakeAmount);
      await staking.connect(user1).stake(stakeAmount);

      expect(await staking.totalStaked()).to.equal(stakeAmount);
    });

    it("Should not allow zero amount stake", async function () {
      await expect(
        staking.connect(user1).stake(0)
      ).to.be.revertedWith("ThesIQStaking: amount must be greater than 0");
    });
  });

  describe("Rewards", function () {
    it("Should calculate rewards correctly", async function () {
      const stakeAmount = ethers.parseEther("100");
      await stakingToken.connect(user1).approve(staking.address, stakeAmount);
      await staking.connect(user1).stake(stakeAmount);

      await time.increase(86400);

      const reward = await staking.calculateReward(user1.address);
      expect(reward).to.be.gt(0);
    });

    it("Should claim rewards", async function () {
      const stakeAmount = ethers.parseEther("100");
      await stakingToken.connect(user1).approve(staking.address, stakeAmount);
      await staking.connect(user1).stake(stakeAmount);

      await time.increase(86400);

      const initialBalance = await rewardToken.balanceOf(user1.address);
      await staking.connect(user1).claimReward();
      const finalBalance = await rewardToken.balanceOf(user1.address);

      expect(finalBalance).to.be.gt(initialBalance);
    });
  });

  describe("Unstaking", function () {
    it("Should allow user to unstake", async function () {
      const stakeAmount = ethers.parseEther("100");
      await stakingToken.connect(user1).approve(staking.address, stakeAmount);
      await staking.connect(user1).stake(stakeAmount);

      const unstakeAmount = ethers.parseEther("50");
      await staking.connect(user1).unstake(unstakeAmount);

      const [amount] = await staking.getStakeInfo(user1.address);
      expect(amount).to.equal(ethers.parseEther("50"));
    });

    it("Should not allow unstaking more than staked", async function () {
      const stakeAmount = ethers.parseEther("100");
      await stakingToken.connect(user1).approve(staking.address, stakeAmount);
      await staking.connect(user1).stake(stakeAmount);

      const unstakeAmount = ethers.parseEther("150");
      await expect(
        staking.connect(user1).unstake(unstakeAmount)
      ).to.be.revertedWith("ThesIQStaking: insufficient staked amount");
    });
  });

  describe("Reward Rate Management", function () {
    it("Should allow owner to set reward rate", async function () {
      const newRate = 200;
      await staking.setRewardRate(newRate);
      expect(await staking.rewardRate()).to.equal(newRate);
    });

    it("Should not allow rate higher than precision", async function () {
      const tooHighRate = 10001;
      await expect(
        staking.setRewardRate(tooHighRate)
      ).to.be.revertedWith("ThesIQStaking: rate too high");
    });

    it("Should not allow non-owner to set rate", async function () {
      const newRate = 200;
      await expect(
        staking.connect(user1).setRewardRate(newRate)
      ).to.be.revertedWithCustomError(staking, "OwnableUnauthorizedAccount");
    });
  });
});