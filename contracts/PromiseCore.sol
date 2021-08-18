// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.4.21 <0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {SafeMath} from "./lib/math/SafeMath.sol";
import {ReentrancyGuard} from "./lib/ReentrancyGuard.sol";
import {ShareCalculator} from "./lib/math/ShareCalculator.sol";
import {PromiseList} from "./PromiseList.sol";

contract PromiseCore is ReentrancyGuard, PromiseList {
    using SafeMath for uint256;
    using ShareCalculator for uint224;

    mapping(uint256 => PromiseData) public promises;
    mapping(uint256 => mapping(bytes32 => PromiseJoinerData)) public joiners;
    mapping(uint256 => uint256) public joinersLength;

    uint256 public lastId;

    address public feeAddress;
    uint256 public feeBP = 50;

    struct PromiseData {
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

    struct PromiseJoinerData {
        uint256 amountPaid;
        uint256 outstandingDebt;
        bool hasExecuted;
    }

    event PromiseCreated(
        uint256 id,
        address creator,
        address creatorToken,
        uint256 creatorAmount,
        address joinerToken,
        uint256 joinerAmount,
        uint256 expirationTimestamp
    );

    event PromiseJoined(uint256 id, address joiner, uint256 amount);
    event PromisePendingAmountClosed(uint256 id, address executor, uint256 refund);
    event PromiseExecuted(uint256 id, address account, uint256 creatorTokenAmount, uint256 joinerTokenAmount);
    event PromisePaid(uint256 id, address account, uint256 amount);

    constructor(address _feeAddress) public {
        feeAddress = _feeAddress;
    }

    function createPromise(
        address account,
        address creatorToken,
        uint112 creatorAmount,
        address joinerToken,
        uint112 joinerAmount,
        uint256 expirationTimestamp
    ) external nonReentrant {
        IERC20(creatorToken).transferFrom(msg.sender, address(this), uint256(creatorAmount).div(2));
        _createPromise(
            account,
            creatorToken,
            uint112(uint256(creatorAmount).div(2).mul(2)),
            joinerToken,
            uint112(uint256(joinerAmount).div(2).mul(2)),
            expirationTimestamp
        );
    }

    function joinPromise(
        uint256 id,
        address account,
        uint112 amount
    ) external nonReentrant {
        //  require(promises[id].expirationTimestamp > block.timestamp, "expirationTimestamp date is in the past and can't be joined");
        require(promises[id].creator != account, "PromiseCore: Can't join your own promise");
        uint256 amountPayingNow = uint256(amount).div(2);
        uint256 remainingJoinerTokenAmountAbleToJoinPromise = getRemainingAmountAbleToJoinPromise(id);
        require(amount <= remainingJoinerTokenAmountAbleToJoinPromise, "PromiseCore: Amount too high for this promise");
        require(amountPayingNow > 0, "PromiseCore: Amount too small");
        IERC20(promises[id].joinerToken).transferFrom(msg.sender, address(this), amountPayingNow);
        _joinPromise(id, account, amountPayingNow);
    }

    function _joinPromise(
        uint256 id,
        address account,
        uint256 amountPayingNow
    ) internal {
        bytes32 joinerId = getJoinerId(id, account);
        if (joiners[id][joinerId].amountPaid == 0) {
            addToAccountList(id, account);
            joinersLength[id]++;
        }
        promises[id].joinerDebt += amountPayingNow;
        joiners[id][joinerId].outstandingDebt += amountPayingNow;
        joiners[id][joinerId].amountPaid += amountPayingNow;
        emit PromiseJoined(id, account, amountPayingNow);
    }

    function payPromise(uint256 id, address account) external nonReentrant {
        // require(promises[id].expirationTimestamp > block.timestamp, "Promise expired");
        if (account == promises[id].creator) {
            require(promises[id].hasCreatorExecuted == false, "PromiseCore: Already executed");
            require(promises[id].creatorDebt > 0, "PromiseCore: OutstandingDebt is 0");
            payAsCreator(id, account);
        } else {
            bytes32 joinerId = getJoinerId(id, account);
            require(joiners[id][joinerId].outstandingDebt > 0, "PromiseCore: OutstandingDebt is 0");
            require(joiners[id][joinerId].hasExecuted == false, "PromiseCore: Already executed");
            payAsJoiner(id, account, joinerId);
        }
    }

    function payAsCreator(uint256 id, address account) internal {
        IERC20(promises[id].creatorToken).transferFrom(msg.sender, address(this), promises[id].creatorDebt);
        promises[id].creatorDebt = 0;
        emit PromisePaid(id, account, promises[id].creatorDebt);
    }

    function payAsJoiner(
        uint256 id,
        address account,
        bytes32 joinerId
    ) internal {
        IERC20(promises[id].joinerToken).transferFrom(msg.sender, address(this), joiners[id][joinerId].outstandingDebt);
        promises[id].joinerDebt -= joiners[id][joinerId].outstandingDebt;
        promises[id].joinerPaidFull += joiners[id][joinerId].outstandingDebt.mul(2);
        joiners[id][joinerId].amountPaid += joiners[id][joinerId].outstandingDebt;
        emit PromisePaid(id, account, joiners[id][joinerId].outstandingDebt);
        joiners[id][joinerId].outstandingDebt = 0;
    }

    function closePendingPromiseAmount(uint256 id) external nonReentrant {
        require(msg.sender == promises[id].creator, "PromiseCore: Only the creator can close");
        uint256 refund = getCreatorRefundAmount(id);
        require(refund > 0, "PromiseCore: Creator has nothing to refund");
        PromiseData storage promiseData = promises[id];
        promiseData.creatorAmount = getRemainingCreatorAmountAfterClosingPromise(id);
        promiseData.joinerAmount = getTotalJoinerFundsInPromise(id);
        promiseData.creatorDebt = 0;
        if (joinersLength[id] == 0) {
            deleteFromAccountList(id, msg.sender);
            promiseData.hasCreatorExecuted = true;
        }
        payout(refund, 0, msg.sender, promiseData.creatorToken, promiseData.joinerToken);
        emit PromisePendingAmountClosed(id, msg.sender, refund);
    }

    function executePromise(uint256 id, address account) external nonReentrant {
        // require(promises[id].expirationTimestamp <= block.timestamp, "This promise has not expired yet");
        if (account == promises[id].creator) {
            require(promises[id].hasCreatorExecuted == false, "PromiseCore: Already executed");
            promises[id].hasCreatorExecuted = true;
            payoutToCreator(id, account);
            deleteFromAccountList(id, account);
        } else {
            bytes32 joinerId = getJoinerId(id, account);
            require(joiners[id][joinerId].hasExecuted == false, "PromiseCore: Already executed");
            require(
                joiners[id][joinerId].outstandingDebt == 0,
                "PromiseCore: Joiner didn't go through with the promise"
            );
            require(joiners[id][joinerId].amountPaid > 0, "PromiseCore: Joiner wasn't in this promise");
            joiners[id][joinerId].hasExecuted = true;
            payoutToJoiner(id, account, joinerId);
            deleteFromAccountList(id, account);
        }
    }

    function payoutToCreator(uint256 id, address account) internal {
        (uint256 creatorTokenPayout, uint256 joinerTokenPayout) = getPayoutAmountsForCreator(id);
        payout(creatorTokenPayout, joinerTokenPayout, account, promises[id].creatorToken, promises[id].joinerToken);
        emit PromiseExecuted(id, account, creatorTokenPayout, joinerTokenPayout);
    }

    function payoutToJoiner(
        uint256 id,
        address account,
        bytes32 joinerId
    ) internal {
        (uint256 creatorTokenPayout, uint256 joinerTokenPayout) = getPayoutAmountsForJoiner(id, joinerId);
        payout(creatorTokenPayout, joinerTokenPayout, account, promises[id].creatorToken, promises[id].joinerToken);
        emit PromiseExecuted(id, account, creatorTokenPayout, joinerTokenPayout);
    }

    function _createPromise(
        address account,
        address creatorToken,
        uint112 creatorAmount,
        address joinerToken,
        uint112 joinerAmount,
        uint256 expirationTimestamp
    ) internal {
        require(
            creatorAmount > 0 && joinerAmount > 0,
            "PromiseCore: One or both of the amounts (creator/joiner) is too small"
        );
        //  require(expirationTimestamp > block.timestamp.add(10 minutes), "expirationTimestamp date is in the past");
        lastId += 1;
        promises[lastId] = PromiseData(
            account,
            creatorToken,
            creatorAmount,
            uint256(creatorAmount).div(2),
            false,
            joinerToken,
            joinerAmount,
            0,
            0,
            expirationTimestamp
        );
        addToAccountList(lastId, account);

        emit PromiseCreated(
            lastId,
            account,
            creatorToken,
            creatorAmount,
            joinerToken,
            joinerAmount,
            expirationTimestamp
        );
    }

    function payout(
        uint256 creatorTokenAmount,
        uint256 joinerTokenAmount,
        address account,
        address creatorAsset,
        address joinerAsset
    ) internal {
        if (creatorTokenAmount > 0) {
            uint256 feeA = creatorTokenAmount.mul(feeBP).div(10000);
            IERC20(creatorAsset).transfer(account, creatorTokenAmount.sub(feeA));
            IERC20(creatorAsset).transfer(feeAddress, feeA);
        }
        if (joinerTokenAmount > 0) {
            uint256 feeB = joinerTokenAmount.mul(feeBP).div(10000);
            IERC20(joinerAsset).transfer(account, joinerTokenAmount.sub(feeB));
            IERC20(joinerAsset).transfer(feeAddress, feeB);
        }
    }

    function getRemainingCreatorAmountAfterClosingPromise(uint256 id) public view returns (uint112) {
        PromiseData memory p = promises[id];
        uint256 creatorAmount = uint256(p.creatorAmount);
        uint256 result = creatorAmount.sub(p.creatorDebt).sub(getCreatorRefundAmount(id));
        return uint112(result);
    }

    function getJoinerId(uint256 id, address account) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, account));
    }

    function getRemainingAmountAbleToJoinPromise(uint256 id) public view returns (uint256) {
        PromiseData memory p = promises[id];
        uint256 existingJoinerTokenAmount = p.joinerPaidFull.add(p.joinerDebt.mul(2));
        return uint256(p.joinerAmount).sub(existingJoinerTokenAmount);
    }

    function getTotalJoinerFundsInPromise(uint256 id) public view returns (uint112) {
        PromiseData memory p = promises[id];
        uint256 result = p.joinerPaidFull.add(p.joinerDebt.mul(2));
        return uint112(result);
    }

    function getCreatorRefundAmount(uint256 id) public view returns (uint256) {
        PromiseData memory p = promises[id];
        uint256 creatorPaid = uint256(p.creatorAmount).sub(p.creatorDebt);
        uint256 tokensUsedByJoiners = divMul(p.creatorAmount, p.joinerAmount, getTotalJoinerFundsInPromise(id));
        return creatorPaid.sub(tokensUsedByJoiners);
    }

    function getPayoutAmountsForCreator(uint256 id) public view returns (uint256, uint256) {
        PromiseData memory p = promises[id];
        return (
            uint256(p.creatorAmount).sub(p.creatorDebt).sub(divMul(p.creatorAmount, p.joinerAmount, p.joinerPaidFull)),
            (p.joinerDebt).add(p.joinerPaidFull)
        );
    }

    function getPayoutAmountsForJoiner(uint256 id, bytes32 joinerId) public view returns (uint256, uint256) {
        PromiseData memory p = promises[id];
        PromiseJoinerData memory j = joiners[id][joinerId];
        uint256 paidByCreator = uint256(p.creatorAmount).sub(p.creatorDebt);
        return (
            divMul(uint112(paidByCreator), p.joinerAmount, (j.amountPaid).sub(j.outstandingDebt.mul(2))),
            p.creatorDebt > 0 ? ((j.amountPaid).sub(j.outstandingDebt)) : 0
        );
    }

    function divMul(
        uint112 a,
        uint112 b,
        uint256 c
    ) public pure returns (uint256 result) {
        result = ShareCalculator.divMul(a, b, uint224(c));
    }
}
