// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ThesIQStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    IERC20 public stakingToken;
    IERC20 public rewardToken;
    
    uint256 public rewardRate = 100;
    uint256 public constant RATE_PRECISION = 10000;
    uint256 public constant REWARD_PERIOD = 1 days;
    
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardTime;
    }
    
    mapping(address => Stake) public stakes;
    uint256 public totalStaked;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    
    constructor(address initialOwner, address _stakingToken, address _rewardToken) Ownable(initialOwner) {
        require(_stakingToken != address(0), "ThesIQStaking: invalid staking token");
        require(_rewardToken != address(0), "ThesIQStaking: invalid reward token");
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }
    
    function stake(uint256 amount) public nonReentrant {
        require(amount > 0, "ThesIQStaking: amount must be greater than 0");
        
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        
        if (stakes[msg.sender].amount > 0) {
            uint256 reward = calculateReward(msg.sender);
            if (reward > 0) {
                rewardToken.safeTransfer(msg.sender, reward);
                emit RewardClaimed(msg.sender, reward);
            }
        }
        
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].startTime = block.timestamp;
        stakes[msg.sender].lastRewardTime = block.timestamp;
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    function unstake(uint256 amount) public nonReentrant {
        require(amount > 0, "ThesIQStaking: amount must be greater than 0");
        require(stakes[msg.sender].amount >= amount, "ThesIQStaking: insufficient staked amount");
        
        uint256 reward = calculateReward(msg.sender);
        if (reward > 0) {
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
        }
        
        stakes[msg.sender].amount -= amount;
        stakes[msg.sender].lastRewardTime = block.timestamp;
        totalStaked -= amount;
        
        stakingToken.safeTransfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    function claimReward() public nonReentrant {
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "ThesIQStaking: no rewards available");
        
        stakes[msg.sender].lastRewardTime = block.timestamp;
        rewardToken.safeTransfer(msg.sender, reward);
        
        emit RewardClaimed(msg.sender, reward);
    }
    
    function calculateReward(address account) public view returns (uint256) {
        Stake memory userStake = stakes[account];
        if (userStake.amount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - userStake.lastRewardTime;
        uint256 reward = (userStake.amount * rewardRate * timeElapsed) / (RATE_PRECISION * REWARD_PERIOD);
        
        return reward;
    }
    
    function setRewardRate(uint256 newRate) public onlyOwner {
        require(newRate <= RATE_PRECISION, "ThesIQStaking: rate too high");
        rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }
    
    function getStakeInfo(address account) public view returns (uint256 amount, uint256 reward) {
        amount = stakes[account].amount;
        reward = calculateReward(account);
    }
}