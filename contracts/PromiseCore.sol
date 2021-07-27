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
        // Any odd amount entered will be converted to an even number so we need to check if the amount
        // is equal to 0 when halved.
        require(creatorAmount / 2 != 0 && joinerAmount / 2 != 0, "Amount too small");
        // Takes the creator amount of the creator token from the message sender before
        // the promise is created.
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
        require(promises[id].creator != account, "Can't join your own promise");
        IERC20(promises[id].joinerToken).transferFrom(msg.sender, address(this), uint256(amount).div(2));
        _joinPromise(id, account, uint112(uint256(amount).div(2).mul(2)));
    }

    function payPromise(uint256 id, address account) external nonReentrant {
        // require(promises[id].expirationTimestamp > block.timestamp, "Promise expired");
        if (account == promises[id].creator) {
            require(promises[id].hasCreatorExecuted == false, "Already executed");
            require(promises[id].creatorDebt > 0, "OutstandingDebt is 0");
            IERC20(promises[id].creatorToken).transferFrom(msg.sender, address(this), promises[id].creatorDebt);
            emit PromisePaid(id, account, promises[id].creatorDebt);
            promises[id].creatorDebt = 0;
        } else {
            bytes32 joinerId = keccak256(abi.encodePacked(id, account));
            require(joiners[id][joinerId].outstandingDebt > 0, "OutstandingDebt is 0");
            require(joiners[id][joinerId].hasExecuted == false, "Already executed");
            IERC20(promises[id].joinerToken).transferFrom(
                msg.sender,
                address(this),
                joiners[id][joinerId].outstandingDebt
            );
            promises[id].joinerDebt -= joiners[id][joinerId].outstandingDebt;
            promises[id].joinerPaidFull += joiners[id][joinerId].outstandingDebt.mul(2);
            joiners[id][joinerId].amountPaid += joiners[id][joinerId].outstandingDebt;
            emit PromisePaid(id, account, joiners[id][joinerId].outstandingDebt);
            joiners[id][joinerId].outstandingDebt = 0;
        }
    }

    function closePendingPromiseAmount(uint256 id) external nonReentrant {
        require(msg.sender == promises[id].creator, "Only the creator can close");
        PromiseData memory p = promises[id];
        // totalJoinerCapital is the amount of the creator token which is set to be given out
        // to all the joiners upon execution. This is removed from the creators refund and the account
        // is sent the amount of creator tokens which is untilised by the joiners.
        uint256 totalJoinerCapital = (p.joinerPaidFull).add(p.joinerDebt.mul(2));
        uint256 refund =
            (uint256(p.creatorAmount).sub(p.creatorDebt)).sub(
                divMul(p.creatorAmount, p.joinerAmount, totalJoinerCapital)
            );
        require(refund > 0, "Creator has nothing to refund");
        promises[id].creatorAmount = uint112(uint256(p.creatorAmount).sub(p.creatorDebt).sub(refund));
        promises[id].joinerAmount = uint112(totalJoinerCapital);
        promises[id].creatorDebt = 0;

        if (joinersLength[id] == 0) {
            deleteFromAccountList(id, msg.sender);
            promises[id].hasCreatorExecuted = true;
        }
        promises[id].creatorDebt = 0;
        payOut(refund, 0, msg.sender, p.creatorToken, p.joinerToken);
        emit PromisePendingAmountClosed(id, msg.sender, refund);
    }

    function executePromise(uint256 id, address account) external nonReentrant {
        // require(promises[id].expirationTimestamp <= block.timestamp, "This promise has not expired yet");
        uint256 creatorTokenPayout;
        uint256 joinerTokenPayout;
        PromiseData memory p = promises[id];
        if (account == promises[id].creator) {
            require(promises[id].hasCreatorExecuted == false, "Already executed");
            // If creator creates a promise, doesn't pay and nobody joins the promise.
            // with this require those funds are just locked forever. This punishment isn't
            // needed because the creator had no joiners.
            // require(promises[id].creatorDebt == 0, "Creator didn't go through with the promise");
            promises[id].hasCreatorExecuted = true;
            creatorTokenPayout = uint256(p.creatorAmount).sub(p.creatorDebt).sub(
                divMul(p.creatorAmount, p.joinerAmount, p.joinerPaidFull)
            );
            joinerTokenPayout = uint256(p.joinerDebt).add(p.joinerPaidFull);
            deleteFromAccountList(id, account);
        } else {
            bytes32 joinerId = keccak256(abi.encodePacked(id, account));
            require(joiners[id][joinerId].hasExecuted == false, "Already executed");
            require(joiners[id][joinerId].outstandingDebt == 0, "Joiner didn't go through with the promise");
            require(joiners[id][joinerId].amountPaid > 0, "Joiner wasn't in this promise");
            joiners[id][joinerId].hasExecuted = true;
            PromiseJoinerData memory j = joiners[id][joinerId];
            creatorTokenPayout = divMul(
                uint112(uint256(p.creatorAmount).sub(p.creatorDebt)),
                p.joinerAmount,
                (j.amountPaid).sub(j.outstandingDebt)
            );
            if (p.creatorDebt > 0) {
                joinerTokenPayout = uint112((j.amountPaid).sub(j.outstandingDebt.mul(2)));
            }
            deleteFromAccountList(id, account);
        }
        payOut(creatorTokenPayout, joinerTokenPayout, account, p.creatorToken, p.joinerToken);
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

    function _joinPromise(
        uint256 id,
        address account,
        uint112 joinerAmount
    ) internal {
        PromiseData storage p = promises[id];
        uint256 remainingJoinableFunds = uint256(p.joinerAmount).sub((p.joinerPaidFull).add(p.joinerDebt.mul(2)));
        uint256 payingNow = uint256(joinerAmount).div(2);
        //  require(p.expirationTimestamp > block.timestamp, "expirationTimestamp date is in the past and can't be joined");
        require(joinerAmount <= remainingJoinableFunds, "Amount too high for this promise");
        require(payingNow > 0, "Amount too small");
        bytes32 joinerId = keccak256(abi.encodePacked(id, account));
        if (joiners[id][joinerId].amountPaid == 0) {
            addToAccountList(id, account);
            joinersLength[id]++;
        }
        promises[id].joinerDebt += payingNow;
        joiners[id][joinerId].outstandingDebt += payingNow;
        joiners[id][joinerId].amountPaid += payingNow;
        remainingJoinableFunds = uint256(p.joinerAmount).sub((p.joinerPaidFull).add(p.joinerDebt.mul(2)));
        // if the maximum amount of tokens have joined the promise, this removes the promise from the joinable linked list

        emit PromiseJoined(id, account, payingNow);
    }

    function payOut(
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

    function divMul(
        uint112 a,
        uint112 b,
        uint256 c
    ) public pure returns (uint256 result) {
        result = ShareCalculator.divMul(a, b, uint224(c));
    }
}
