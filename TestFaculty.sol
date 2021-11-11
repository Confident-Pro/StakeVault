// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TestFaculty is Ownable {
	using SafeMath for uint256;

	uint256 constant public DEPOSIT_MIN_AMOUNT = 1e16; // 0.01 eth
	uint256 constant public TIME_STEP = 1 days;
    uint256 constant private REWARD_PER_BLOCK = 1e20;
	uint256 constant private REWARD_PERCENT = 1;

	uint256 public totalInvested;
	uint256 public lockTime;
	uint256 public lastRewardBlock;

    IERC20 public immutable rewardToken;

	struct User {
        uint256 start; // deposit start time
        uint256 checkPoint; // last harvest time
		uint256 amount; // deposit amount
		uint256 reward; // total reward amount
        uint64 lockBlock; // lock block number
	}

	mapping (address => User) internal users;

	event Deposit(address indexed user, uint256 amount, uint256 block);
	event Withdrawn(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount, address indexed to);

	constructor(IERC20 _rewardToken, uint256 _period) {
        rewardToken = _rewardToken;
		lockTime = _period.add(block.timestamp);
        lastRewardBlock = block.number;
	}

	function deposit(uint64 _lockBlock) public payable {
        require(block.timestamp < lockTime, "The deposit period is over.");
		require(msg.value >= DEPOSIT_MIN_AMOUNT, "The deposit amount should be over 0.01 eth.");
		User storage user = users[msg.sender];
        user.start = block.timestamp;
        user.amount = user.amount.add(msg.value);
        user.lockBlock = _lockBlock;
		totalInvested = totalInvested.add(msg.value);
		emit Deposit(msg.sender, msg.value, _lockBlock);
	}

	function withdraw(uint256 _amount) public {
		User storage user = users[msg.sender];
		require(user.amount >= _amount, "User has no dividends");
		require(user.lockBlock < block.number, "You can't withdraw yet.");
        user.amount = user.amount.sub(_amount);
        totalInvested = totalInvested.sub(_amount);
		payable(msg.sender).transfer(_amount);
		emit Withdrawn(msg.sender, _amount);
	}

    function harvest() public {
        require(totalInvested > 0, "The total inveted amount should be over 0.");
		User storage user = users[msg.sender];
        uint256 rewardAmount = getUserReward(msg.sender);
        require(rewardAmount > 0, "The reward amount should be over 0.");
        user.reward = user.reward.add(rewardAmount);
        user.checkPoint = block.timestamp;
        lastRewardBlock = block.number;
        if (rewardAmount != 0) {
            rewardToken.transfer(msg.sender, rewardAmount);
        }
        emit Harvest(msg.sender, rewardAmount);
    }
    
	function getUserReward(address _userAddress) public view returns (uint256) {
        require(totalInvested > 0, "The total inveted amount should be over 0.");
		User memory user = users[_userAddress];
		uint256 totalAmount;
        uint256 blocks = block.number.sub(lastRewardBlock);
        uint256 rewardAmount = blocks.mul(rewardPerBlock()).mul(user.amount).div(totalInvested);
        uint256 from = user.start > user.checkPoint ? user.start : user.checkPoint;
        uint256 to = block.timestamp;
        if (from < to) {
            totalAmount = rewardAmount.mul(to.sub(from).div(TIME_STEP));
        }
		return totalAmount;
	}

    function emergencyWithdraw(address to) public onlyOwner {
        User storage user = users[to];
        uint256 _amount = user.amount;
        require(_amount > 0, "The amount should be over 0.");
        user.amount = 0;
        user.checkPoint = block.timestamp;
		payable(to).transfer(_amount);
        emit EmergencyWithdraw(msg.sender, _amount, to);
    }

    function rewardPerBlock() public pure returns (uint256 amount) {
        amount = uint256(REWARD_PER_BLOCK).mul(REWARD_PERCENT).div(1000);
    }

	function getCurrentBlock() public view returns (uint256) {
		return block.number;
	}

	function getContractBalance() public view returns (uint256) {
		return address(this).balance;
	}
}