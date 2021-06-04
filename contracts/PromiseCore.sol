// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.4.21 <0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {SafeMath} from "./lib/math/SafeMath.sol";
import {ReentrancyGuard} from "./lib/ReentrancyGuard.sol";
import {ShareCalculator} from "./lib/math/ShareCalculator.sol";

contract PromiseCore is ReentrancyGuard {
    using SafeMath for uint256;
    using ShareCalculator for uint224;

    address public feeAddress;
    uint256 public fee = 3;
    uint256 public startBlockTime;

    mapping(uint256 => PromData) public promises;
    mapping(uint256 => mapping(bytes32 => Promjoiners)) public joiners;
    mapping(uint256 => uint256) public joinersLength;

    mapping(bytes32 => LinkedList) public list;
    mapping(bytes32 => bytes32) tail;
    mapping(bytes32 => uint256) length;

    uint256 public lastId;

    struct PromData {
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

    struct Promjoiners {
        uint256 amountPaid;
        uint256 outstandingDebt;
        bool hasExecuted;
    }

    struct LinkedList {
        bytes32 next;
        uint256 id;
        bytes32 previous;
    }

    event PromiseCreated(
        address creator,
        address creatorToken,
        uint256 creatorAmount,
        address joinerToken,
        uint256 joinerAmount,
        uint256 expirationTimestamp
    );

    event PromiseJoined(address addrB, uint256 id, uint256 amount);
    event PromiseCanceled(address executor, uint256 id);
    event PromiseExecuted(address executor, uint256 id);
    event PromisePaid(address Payee, uint256 id, uint256 remainingDebt);

    constructor(address _feeAddress) public {
        feeAddress = _feeAddress;
        startBlockTime = block.timestamp;
    }

    function createPromise(
        address account,
        address creatorToken,
        uint112 creatorAmount,
        address joinerToken,
        uint112 joinerAmount,
        uint256 expirationTimestamp
    ) external nonReentrant {
        require(creatorAmount / 2 != 0 && joinerAmount / 2 != 0, "Amount too small");
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
            promises[id].creatorDebt = 0;
            emit PromisePaid(account, id, promises[id].creatorDebt);
        } else {
            bytes32 joinerId = sha256(abi.encodePacked(id, account));
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
            joiners[id][joinerId].outstandingDebt = 0;
            emit PromisePaid(account, id, joiners[id][joinerId].outstandingDebt);
        }
    }

    function closePendingPromiseAmount(uint256 id) external nonReentrant {
        require(msg.sender == promises[id].creator, "Only the creator can close");
        PromData memory p = promises[id];
        /*      
        Calculate how much needs to be refunded
        this is only the capital which is not being utilised by the joiners. 
        No joiners means all capital added by the creator is refunded.
       */
        uint256 totalJoinerCapital = (p.joinerPaidFull).add(p.joinerDebt.mul(2));
        uint256 refund =
            (uint256(p.creatorAmount).sub(p.creatorDebt)).sub(
                shareCal(p.creatorAmount, p.joinerAmount, totalJoinerCapital)
            );

        promises[id].creatorAmount = uint112(uint256(p.creatorAmount).sub(p.creatorDebt).sub(refund.div(2).mul(2)));
        promises[id].joinerAmount = uint112(totalJoinerCapital);
        promises[id].creatorDebt = 0;
        deleteFromJoinableList(id, p.creatorToken, p.joinerToken);
        if (joinersLength[id] == 0) {
            deleteFromAccountList(id, msg.sender);
            promises[id].hasCreatorExecuted = true;
        }
        require(refund > 0, "nothing to refund");
        IERC20(p.creatorToken).transfer(p.creator, refund);
        promises[id].creatorDebt = 0;
        emit PromiseCanceled(msg.sender, id);
    }

    function executePromise(uint256 id, address account) external nonReentrant {
        // require(promises[id].expirationTimestamp <= block.timestamp, "This promise has not expired yet");
        uint256 creatorAmount;
        uint256 joinerAmount;
        PromData memory p = promises[id];
        if (account == promises[id].creator) {
            require(promises[id].hasCreatorExecuted == false, "Already executed");
            require(promises[id].creatorDebt == 0, "Creator didn't go through with the promise");
            promises[id].hasCreatorExecuted = true;
            creatorAmount = uint256(p.creatorAmount).sub(p.creatorDebt.mul(2)).sub(
                shareCal(p.creatorAmount, p.joinerAmount, p.joinerPaidFull)
            );
            joinerAmount = uint256(p.joinerDebt).add(p.joinerPaidFull);
            payOut(creatorAmount, joinerAmount, account, p.creatorToken, p.joinerToken);
            deleteFromAccountList(id, account);
            deleteFromJoinableList(id, p.creatorToken, p.joinerToken);
        } else {
            bytes32 joinerId = sha256(abi.encodePacked(id, account));
            require(joiners[id][joinerId].hasExecuted == false, "Already executed");
            require(joiners[id][joinerId].outstandingDebt == 0, "Joiner didn't go through with the promise");
            joiners[id][joinerId].hasExecuted = true;
            Promjoiners memory j = joiners[id][joinerId];
            creatorAmount = shareCal(
                uint112(uint256(p.creatorAmount).sub(uint256(p.creatorDebt))),
                p.joinerAmount,
                (j.amountPaid).sub(j.outstandingDebt)
            );
            joinerAmount = 0;
            if (p.creatorDebt > 0) {
                joinerAmount = uint112((j.amountPaid).sub(j.outstandingDebt.mul(2)));
            }
            payOut(creatorAmount, joinerAmount, account, p.creatorToken, p.joinerToken);
            deleteFromAccountList(id, account);
            deleteFromJoinableList(id, p.creatorToken, p.joinerToken);
        }

        emit PromiseExecuted(account, id);
    }

    function _createPromise(
        address account,
        address creatorToken,
        uint112 creatorAmount,
        address joinerToken,
        uint112 joinerAmount,
        uint256 expirationTimestamp
    ) internal {
        //require(expirationTimestamp > block.timestamp.add(10 minutes), "expirationTimestamp date is in the past");
        lastId += 1;
        promises[lastId] = PromData(
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
        addToJoinableList(creatorToken, joinerToken, expirationTimestamp);
        bytes32 listId = sha256(abi.encodePacked(account));
        bytes32 entry = sha256(abi.encodePacked(listId, lastId));
        addEntry(lastId, listId, entry);

        emit PromiseCreated(account, creatorToken, creatorAmount, joinerToken, joinerAmount, expirationTimestamp);
    }

    function _joinPromise(
        uint256 id,
        address account,
        uint112 _amount
    ) internal {
        PromData memory p = promises[id];
        bytes32 joinerId = sha256(abi.encodePacked(id, account));
        uint256 leftOverjoinerAmount = uint256(p.joinerAmount).sub((p.joinerPaidFull).add(p.joinerDebt.mul(2)));
        //require(p.expirationTimestamp > block.timestamp, "expirationTimestamp date is in the past and can't be joined");
        require(_amount <= leftOverjoinerAmount, "Amount too high for this promise");
        /*        
       Adding entries to two linked lists:
       firstly adding this account and info (amountPaid, outstandingDebt, executed) to the list of joiner info for this promise
       secondly adding this promise to a list of promises the account is involved with 
       */
        bytes32 listId = sha256(abi.encodePacked(id));
        bytes32 entry = sha256(abi.encodePacked(listId, account));
        addEntry(joinersLength[id], listId, entry);
        if (joiners[id][joinerId].amountPaid == 0) {
            listId = sha256(abi.encodePacked(account));
            entry = sha256(abi.encodePacked(listId, id));
            addEntry(id, listId, entry);
        }
        uint256 amount = uint256(_amount).div(2);
        require(amount > 0, "Amount too small");
        /*        
         amount is not added to joinerPaidFull on join as this payment is irrelevant until outstandingDebt is paid in full
       */
        promises[id].joinerDebt += amount;
        joiners[id][joinerId].outstandingDebt += amount;
        joiners[id][joinerId].amountPaid += amount;
        joinersLength[id]++;
        /*        
         if the maximum amount of tokens have joined the promise, this removes the promise from the joinable linked list 
       */
        p = promises[id];
        leftOverjoinerAmount = uint256(p.joinerAmount).sub((p.joinerPaidFull).add(p.joinerDebt.mul(2)));
        if (leftOverjoinerAmount == 0) {
            deleteFromJoinableList(id, p.creatorToken, p.joinerToken);
        }

        emit PromiseJoined(account, id, amount);
    }

    function payOut(
        uint256 amountA,
        uint256 amountB,
        address account,
        address assetA,
        address assetB
    ) internal {
        uint256 feeA = shareCal(uint112(amountA), 1000, fee);
        uint256 feeB = shareCal(uint112(amountB), 1000, fee);
        IERC20(assetA).transfer(account, amountA.sub(feeA));
        IERC20(assetB).transfer(account, amountB.sub(feeB));
        IERC20(assetA).transfer(feeAddress, feeA);
        IERC20(assetB).transfer(feeAddress, feeB);
    }

    function addEntry(
        uint256 id,
        bytes32 listId,
        bytes32 entry
    ) internal {
        if (length[listId] > 0) {
            list[tail[listId]].next = entry;
            list[entry].id = id;
            list[entry].previous = tail[listId];
            tail[listId] = entry;
        } else {
            list[listId].id = id;
            tail[listId] = listId;
        }
        length[listId] += 1;
    }

    function deleteEntry(
        uint256 id,
        bytes32 listId,
        bytes32 index
    ) internal {
        if (list[listId].id != id && list[index].id == id) {
            if (list[index].next != "") {
                list[list[index].next].previous = list[index].previous;
            }
            if (list[index].previous != "") {
                list[list[index].previous].next = list[index].next;
                if (tail[listId] == index) {
                    tail[listId] = list[index].previous;
                }
            }
            list[index].previous = "";
            list[index].next = "";
            length[listId] -= 1;
        } else if (list[listId].id == id) {
            list[listId].id = list[list[listId].next].id;
            list[listId].next = list[list[listId].next].next;
            length[listId] -= 1;
        }
    }

    function deleteFromAccountList(uint256 id, address account) internal {
        bytes32 listId = sha256(abi.encodePacked(account));
        bytes32 index = sha256(abi.encodePacked(listId, id));
        deleteEntry(id, listId, index);
    }

    function deleteFromJoinableList(
        uint256 id,
        address creatorToken,
        address joinerToken
    ) internal {
        bytes32 listId = sha256(abi.encodePacked(creatorToken, joinerToken));
        bytes32 index = sha256(abi.encodePacked(listId, id));
        deleteEntry(id, listId, index);
    }

    function addToJoinableList(
        address creatorToken,
        address joinerToken,
        uint256 expirationTimestamp
    ) internal {
        uint256 expirationMonth = (startBlockTime.sub(expirationTimestamp)).div(30 days);
        bytes32 listId = sha256(abi.encodePacked(creatorToken, joinerToken, expirationMonth));
        bytes32 entry = sha256(abi.encodePacked(listId, lastId));
        addEntry(lastId, listId, entry);
    }

    function shareCal(
        uint112 a,
        uint112 b,
        uint256 c
    ) public view returns (uint256 z) {
        z = ShareCalculator.divMul(a, b, uint224(c));
    }

    function joinablePromises(
        address _creatorToken,
        address _joinerToken,
        uint256 _earliestExpirationDate,
        uint256 _latestExpirationDate /* 
        uint256 toCreatorTokenJoinerTokenRatio,
        uint256 fromCreatorTokenJoinerTokenRatio */
    )
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory creatorAmount,
            uint256[] memory joinerAmount,
            uint256[] memory expirationTimestamp
        )
    {
        bytes32 listId = sha256(abi.encodePacked(_creatorToken, _joinerToken));
        uint256 _length = length[listId];

        id = new uint256[](_length);
        creatorAmount = new uint256[](_length);
        joinerAmount = new uint256[](_length);
        expirationTimestamp = new uint256[](_length);

        uint256 i;
        bytes32 index = listId;
        PromData memory p;
        while (i < _length) {
            id[i] = list[index].id;
            p = promises[id[i]];
            creatorAmount[i] = uint256(p.creatorAmount).sub(
                shareCal(p.creatorAmount, p.joinerAmount, (p.joinerPaidFull).add(p.joinerDebt.mul(2)))
            );
            joinerAmount[i] = uint256(p.joinerAmount).sub((p.joinerPaidFull).add(p.joinerDebt.mul(2)));
            expirationTimestamp[i] = p.expirationTimestamp;
            index = list[index].next;

            i += 1;
        }
    }

    function accountPromises(address account)
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory outstandingDebt,
            uint256[] memory receiving,
            uint256[] memory expirationTimestamp,
            address[] memory tokens
        )
    {
        bytes32 listId = sha256(abi.encodePacked(account));
        uint256 _length = length[listId];

        id = new uint256[](_length);
        outstandingDebt = new uint256[](_length);
        receiving = new uint256[](_length);
        expirationTimestamp = new uint256[](_length);
        // tokens array is twice the length because it has 2 entries added every loop
        tokens = new address[](_length.mul(2));

        uint256 i;
        bytes32 index = listId;
        PromData memory p;
        Promjoiners memory j;
        while (i < _length) {
            id[i] = list[index].id;
            p = promises[id[i]];
            tokens[i > 0 ? i * 2 : 0] = p.creatorToken;
            tokens[i > 0 ? (i * 2) - 1 : 1] = p.joinerToken;
            if (p.creator == account) {
                outstandingDebt[i] = p.creatorDebt;
                receiving[i] = uint256(p.joinerDebt).add(p.joinerPaidFull);
            } else {
                bytes32 joinerId = sha256(abi.encodePacked(id[i], account));
                j = joiners[id[i]][joinerId];
                outstandingDebt[i] = j.outstandingDebt;
                receiving[i] = shareCal(p.creatorAmount, p.joinerAmount, (j.amountPaid).add(j.outstandingDebt));
            }
            expirationTimestamp[i] = p.expirationTimestamp;
            index = list[index].next;
            i += 1;
        }
    }
}
