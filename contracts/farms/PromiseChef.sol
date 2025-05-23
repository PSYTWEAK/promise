// SPDX-License-Identifier: MIT

pragma solidity >=0.4.21 <0.8.0;

import {SafeMath} from "../lib/math/SafeMath.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "../lib/SafeERC20.sol";
import {Ownable} from "../lib/Ownable.sol";

import {PromiseToken} from "../token/PromiseToken.sol";
import {PromiseCore} from "../PromiseCore.sol";
import {PromiseList} from "../PromiseList.sol";
import {IPromiseHolder} from "../interfaces/IPromiseHolder.sol";

contract PromiseChef is Ownable, PromiseList {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 creatorToken;
        address joinerToken;
        uint256 minRatio;
        uint256 maxRatio;
        uint256 allocPoint; // How many allocation points assigned to this pool. PROMs to distribute per block.
        uint256 lastRewardBlock; // Last block number that PROMs distribution occurs.
        uint256 accPromPerShare; // Accumulated PROMs per share, times 1e12. See below.
        uint256 expirationDate;
        uint256 lpSupply;
    }
    struct PromiseCoreData {
        address creator;
        address creatorToken;
        uint112 creatorAmount;
        uint256 creatorDebt;
        bool hasCreatorExecuted;
        address joinerToken;
        uint112 joinerAmount;
        uint256 joinerDebt;
        uint256 joinerPaidFull;
        uint256 expirationTimestamp;
    }

    // The PROM TOKEN!
    PromiseToken public prom;
    // PromiseCore
    PromiseCore public promiseCore;
    // PROM tokens created per block.
    uint256 public promPerBlock;
    // Bonus muliplier for early prom makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    // Promise holder address;
    address public promiseHolder;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each promise that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // The last prom rewards claim fo this user.
    mapping(address => uint256) public lastClaim;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when PROM mining starts.
    uint256 public startBlock;
    // The block when PROM mining stops.
    uint256 public endBlock;

    constructor(
        PromiseToken _prom,
        PromiseCore _promiseCore,
        uint256 _promPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) public Ownable(msg.sender) {
        prom = _prom;
        promiseCore = _promiseCore;
        promPerBlock = _promPerBlock;
        startBlock = block.number;
        endBlock = _endBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _creatorToken,
        address _joinerToken,
        uint256[2] memory _minUncalculatedRatio,
        uint256[2] memory _maxUncalculatedRatio,
        bool _withUpdate,
        uint256 _expirationDate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                creatorToken: _creatorToken,
                joinerToken: _joinerToken,
                minRatio: calculateRatio(_minUncalculatedRatio[0], _minUncalculatedRatio[1]),
                maxRatio: calculateRatio(_maxUncalculatedRatio[0], _maxUncalculatedRatio[1]),
                expirationDate: _expirationDate,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPromPerShare: 0,
                lpSupply: 0
            })
        );
        IPromiseHolder(promiseHolder).approvePromiseChef(address(_creatorToken));
        _creatorToken.approve(address(promiseCore), 2**256 - 1);
    }

    // Update the given pool's PROM allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending PROMs on frontend.
    function pendingProm(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPromPerShare = pool.accPromPerShare;
        uint256 lpSupply = pool.lpSupply;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 promReward = multiplier.mul(promPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accPromPerShare = accPromPerShare.add(promReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accPromPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;
        if (lastBlock <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpSupply;

        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = lastBlock;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, lastBlock);
        uint256 promReward = multiplier.mul(promPerBlock).mul(pool.allocPoint).div(totalAllocPoint);

        pool.accPromPerShare = pool.accPromPerShare.add(promReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = lastBlock;
    }

    // Deposit LP tokens to MasterChef for PROM allocation.
    function createPromise(
        uint256 _pid,
        uint256 _creatorAmount,
        uint256 _joinerAmount
    ) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 creatorAmount = uint112(_creatorAmount.div(2).mul(2));
        uint256 ratio = calculateRatio(_creatorAmount, _joinerAmount);
        require(
            ratio >= pool.minRatio && ratio <= pool.maxRatio,
            "the ratio between creator and joiner tokens is out of range"
        );
        updatePool(_pid);
        if (creatorAmount > 0) {
            pool.creatorToken.safeTransferFrom(address(msg.sender), address(this), creatorAmount.div(2));
            pool.lpSupply = pool.lpSupply.add(creatorAmount);
            promiseCore.createPromise(
                promiseHolder,
                address(pool.creatorToken),
                uint112(creatorAmount),
                pool.joinerToken,
                uint112(_joinerAmount),
                pool.expirationDate
            );
            user.amount = user.amount.add(creatorAmount);
            addToAccountList(promiseCore.lastId(), msg.sender);
            user.rewardDebt = user.amount.mul(pool.accPromPerShare).div(1e12);
        }
    }

    function payPromise(uint256 id) external {
        (, address creatorToken, , uint256 creatorDebt, , , , , , ) = promiseCore.promises(id);
        IERC20(creatorToken).transferFrom(msg.sender, address(this), creatorDebt);
        promiseCore.payPromise(id, promiseHolder);
    }

    function executePromise(
        uint256 _pid,
        uint256 promiseId,
        address account
    ) external {
        PromiseCoreData memory p;
        (
            ,
            p.creatorToken,
            p.creatorAmount,
            p.creatorDebt,
            p.hasCreatorExecuted,
            p.joinerToken,
            p.joinerAmount,
            p.joinerDebt,
            p.joinerPaidFull,

        ) = promiseCore.promises(promiseId);
        bytes32 listId = keccak256(abi.encodePacked(account));
        bytes32 index = keccak256(abi.encodePacked(keccak256(abi.encodePacked(account)), promiseId));
        require(
            list[listId].id == promiseId || list[index].id == promiseId,
            "Message sender is not the creator of this promise"
        );
        deleteFromAccountList(promiseId, account);

        if (!p.hasCreatorExecuted) {
            promiseCore.executePromise(promiseId, promiseHolder);
        }
        uint256 creatorTokenPayout =
            uint256(p.creatorAmount).sub(p.creatorDebt).sub(
                promiseCore.divMul(uint112(p.creatorAmount), uint112(p.joinerAmount), p.joinerPaidFull)
            );
        uint256 joinerTokenPayout = uint256(p.joinerDebt).add(p.joinerPaidFull);
        withdrawFromPool(_pid, p.creatorAmount, account);
        if (creatorTokenPayout > 0) {
            creatorTokenPayout = creatorTokenPayout.sub((creatorTokenPayout).mul(promiseCore.feeBP()).div(10000));
            IERC20(p.creatorToken).transferFrom(promiseHolder, account, creatorTokenPayout);
        }
        if (joinerTokenPayout > 0) {
            joinerTokenPayout = joinerTokenPayout.sub((joinerTokenPayout).mul(promiseCore.feeBP()).div(10000));
            IERC20(p.joinerToken).transferFrom(promiseHolder, account, joinerTokenPayout);
        }
    }

    function closePendingPromiseAmount(uint256 _pid, uint256 promiseId) external {
        PoolInfo storage pool = poolInfo[_pid];
        bytes32 listId = keccak256(abi.encodePacked(msg.sender));
        bytes32 index = keccak256(abi.encodePacked(listId, promiseId));
        require(
            list[listId].id == promiseId || list[index].id == promiseId,
            "Message sender is not the creator of this promise"
        );
        uint256 promiseHolderBalance = pool.creatorToken.balanceOf(promiseHolder);
        IPromiseHolder(promiseHolder).closePendingPromiseAmount(promiseId);
        uint256 creatorTokenRefund = (pool.creatorToken.balanceOf(promiseHolder)).sub(promiseHolderBalance);
        (, address creatorToken, uint256 creatorAmount, , , address joinerToken, , , , ) =
            promiseCore.promises(promiseId);
        require(
            creatorToken == address(pool.creatorToken) && joinerToken == pool.joinerToken,
            "This promise was not created with this pool"
        );
        if (creatorAmount == 0) {
            deleteFromAccountList(promiseId, msg.sender);
        }
        withdrawFromPool(_pid, creatorTokenRefund, msg.sender);
        IERC20(pool.creatorToken).transferFrom(promiseHolder, msg.sender, creatorTokenRefund);
    }

    function claimReward(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accPromPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safePromTransfer(msg.sender, pending);
        }
        user.rewardDebt = user.amount.mul(pool.accPromPerShare).div(1e12);
    }

    // Withdraw LP tokens from MasterChef.
    function withdrawFromPool(
        uint256 _pid,
        uint256 _amount,
        address account
    ) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][account];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accPromPerShare).div(1e12).sub(user.rewardDebt);
        safePromTransfer(account, pending);
        pool.lpSupply = pool.lpSupply.add(_amount);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accPromPerShare).div(1e12);
    }

    // Safe prom transfer function, just in case if rounding error causes pool to not have enough PROMs.
    function safePromTransfer(address _to, uint256 _amount) internal {
        uint256 promBal = prom.balanceOf(address(this));
        if (_amount > promBal) {
            prom.transfer(_to, promBal);
        } else {
            prom.transfer(_to, _amount);
        }
    }

    function setPromiseHolder(address _promiseHolder) public onlyOwner {
        promiseHolder = _promiseHolder;
    }

    //Pancake has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _promPerBlock) public onlyOwner {
        massUpdatePools();
        promPerBlock = _promPerBlock;
    }

    function calculateRatio(uint256 creatorAmount, uint256 joinerAmount) public pure returns (uint256 z) {
        z = creatorAmount.mul(1 ether).div(joinerAmount);
    }
}
