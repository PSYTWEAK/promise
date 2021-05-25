// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.8.0;


import { IERC20 } from "../interfaces/IERC20.sol";
import { Math } from  "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol";
import { SafeMath } from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import { SafeERC20 } from "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";


// Inheritance
import { RewardsDistributionRecipient } from  "../lib/RewardsDistributionRecipient.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IPromController} from "../interfaces/IPromController.sol";

contract EthFarm is RewardsDistributionRecipient, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IWETH public stakingToken;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 60 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    address public WETH;
    address public DAI;
    address public prom;

    PromiseOptions[3] public promiseOptions;
    
    struct PromiseOptions {
        uint256 ratio;
        uint256 time;
    }
    
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(uint256 => bool) public logged;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _rewardsToken,
        address _stakingToken,
        address _dai,
        address _prom
    ) public {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        WETH = _stakingToken
        DAI = _dai;
        prom = _prom;
        rewardsDistribution = msg.sender;
        // change before production
        for (uint256 i; i < 3; i++) {
            promiseOptions[i].ratio = 1000 + i;
            promiseOptions[i].time = 1631019788 + i;
        }
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply));
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function createPromise(uint256 optionIndex) external payable nonReentrant updateReward(msg.sender) {
        uint256 amountB = (msg.value.mul(promiseOptions[optionIndex].ratio));
        stakingToken.deposit{value: msg.value}();
        IPromController(prom).createPromise(msg.sender, (msg.value).mul(2), address(stakingToken), amountB, DAI, promiseOptions[optionIndex].time);
        emit PromiseCreatedInFarm(msg.sender, amountB);
    }
    
    function logPromiseAfterJoined(uint id) external nonReentrant updateReward(msg.sender) {
        require(logged[id] == false);
        logged[id] = true;
            uint amountA;
           address assetA;
    uint amountB;
    address assetB;
    uint time;
    bool executed;
    address addrA;
    address addrB;
    (amountA,assetA,amountB,assetB,time,executed) = IPromController(prom).getPromiseData_Amount_Asset_Time_Executed(id);
    (addrA, addrB) = IPromController(prom).getPromiseData_Addr(id);

        // commented while testing
        // require(executed == true);
        require(addrA == msg.sender);
        _totalSupply = _totalSupply.add(amountA);
        _balances[msg.sender] = _balances[msg.sender].add(amountA);
    }

    function getReward(uint id) public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }


    function setRatios(uint256[3] memory _ratios, uint256[3] memory _times) external onlyRewardsDistribution {
        for (uint256 i; i < 3;i++) {
            promiseOptions[i].ratio = _ratios[i];
            promiseOptions[i].time = _times[i];
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */
    
    function approveProm() external onlyRewardsDistribution {
        stakingToken.approve(prom, 2**256 - 1);
    }

    function notifyRewardAmount(uint256 reward) external override onlyRewardsDistribution updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event PromiseCreatedInFarm(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
}
