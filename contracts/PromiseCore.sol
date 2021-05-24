// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.4.21 <0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {SafeMath} from "./lib/SafeMath.sol";
import {ReentrancyGuard} from "./lib/ReentrancyGuard.sol";
import {ShareCalculator} from "./lib/ShareCalculator.sol";

contract PromiseCore is ReentrancyGuard {
    using SafeMath for uint256;
    using ShareCalculator for uint224;

    address public feeAddress;

    mapping(uint256 => PromData) public promises;
    mapping(uint256 => mapping(bytes32 => Promjoiners)) public joiners;
    mapping(uint256 => uint256) public joinersLength;

    mapping(bytes32 => LinkedList) public list;
    mapping(bytes32 => bytes32) tail;
    mapping(bytes32 => uint256) length;

    uint256 public lastId;

    struct PromData {
        address creator;
        address cToken;
        uint112 cAmount;
        uint256 cDebt;
        bool cExecuted;
        address jToken;
        uint112 jAmount;
        uint256 jDebt;
        uint256 jPaid;
        uint256 expiry;
    }

    struct Promjoiners {
        uint256 paid;
        uint256 debt;
        bool executed;
    }

    struct LinkedList {
        bytes32 next;
        uint256 id;
        bytes32 previous;
    }

    event PromiseCreated(
        address creator,
        address cToken,
        uint256 cAmount,
        address jToken,
        uint256 jAmount,
        uint256 expiry
    );

    event PromiseJoined(address addrB, uint256 id, uint256 amount);
    event PromiseCanceled(address executor, uint256 id);
    event PromiseExecuted(address executor, uint256 id);

    constructor(address _feeAddress) public {
        feeAddress = _feeAddress;
    }

    function createPromise(
        address account,
        address cToken,
        uint112 cAmount,
        address jToken,
        uint112 jAmount,
        uint256 expiry
    ) external nonReentrant {
        require(cAmount / 2 != 0 && jAmount / 2 != 0, "Amount too small");
        IERC20(cToken).transferFrom(msg.sender, address(this), uint256(cAmount).div(2));
        _createPromise(account, cToken, cAmount, jToken, jAmount, expiry);
    }

    function joinPromise(
        uint256 id,
        address account,
        uint112 amount
    ) external nonReentrant {
        require(promises[id].creator != account, "Can't join your own promise");
        IERC20(promises[id].jToken).transferFrom(msg.sender, address(this), amount);
        _joinPromise(id, account, amount);
    }

    function payPromise(uint256 id, address account) external nonReentrant {
        if (account == promises[id].creator) {
            IERC20(promises[id].cToken).transferFrom(msg.sender, address(this), promises[id].cDebt);
            promises[id].cDebt = 0;
        } else {
            bytes32 jid = sha256(abi.encodePacked(id, account));
            require(joiners[id][jid].debt > 0, "debt is 0");
            IERC20(promises[id].jToken).transferFrom(msg.sender, address(this), joiners[id][jid].debt);
            promises[id].jDebt -= joiners[id][jid].debt;
            promises[id].jPaid += uint112(uint256(joiners[id][jid].debt).mul(2));
            joiners[id][jid].paid = uint112(uint256(joiners[id][jid].debt).mul(2));
            joiners[id][jid].debt = 0;
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
        uint256 x = uint256((p.jDebt).mul(2) + p.jPaid);
        uint256 refund = uint256(p.cAmount).sub(p.cDebt).sub(shareCal(p.cAmount, p.jAmount, x));
        promises[id].cAmount -= uint112(refund);
        promises[id].jAmount = uint112(x);
        /*      
        delete entries from 2 linked lists
        First, deletes from the relevant joinablePromise list so its not advertised to people anymore
        second, deletes from the account promises if nobody joined 
       */
        bytes32 listId = sha256(abi.encodePacked(p.cToken, p.jToken));
        bytes32 index = sha256(abi.encodePacked(listId, id));
        deleteEntry(id, listId, index);

        if (joinersLength[id] == 0) {
            listId = sha256(abi.encodePacked(msg.sender));
            index = sha256(abi.encodePacked(listId, id));
            deleteEntry(id, listId, index);
            promises[id].cExecuted = true;
        }
        IERC20(p.cToken).transfer(p.creator, refund);
        emit PromiseCanceled(msg.sender, id);
    }

    /*        
        executing a promise
        if you are the creator id should be the id of the promise you are referencing and jId should be 0
        if you are a joiner, you need the promise id (id) and your own joiner Id (jid)
        Checks whether you are the creator or join and then gives you the required payout.
       */
    function executePromise(uint256 id, address account) external nonReentrant {
        require(promises[id].expiry <= block.timestamp, "This promise has not expired yet");
        uint256 amA;
        uint256 amB;
        PromData memory p = promises[id];
        if (account == promises[id].creator) {
            require(promises[id].cExecuted == false, "already executed");
            require(promises[id].cDebt == 0, "Creator didn't go through with the promise");
            promises[id].cExecuted = true;
            uint256 x = uint256((p.jDebt).mul(2).add(p.jPaid));
            amA = uint256(p.cAmount).sub(shareCal(p.cAmount, p.jAmount, x));
            amB = uint256(p.jDebt).add(p.jPaid);
            payOut(amA, amB, account, p.cToken, p.jToken);
            bytes32 listId = sha256(abi.encodePacked(account));
            bytes32 index = sha256(abi.encodePacked(listId, id));
            deleteEntry(id, listId, index);
        } else {
            bytes32 jid = sha256(abi.encodePacked(id, account));
            require(joiners[id][jid].executed == false, "already executed");
            require(joiners[id][jid].debt == 0, "Joiner didn't go through with the promise");
            joiners[id][jid].executed = true;
            Promjoiners memory joiners = joiners[id][jid];
            amA = (uint256(p.cAmount).sub(p.cDebt)).div(p.jAmount).mul(joiners.paid);
            amB = 0;
            if (p.cDebt > 0) {
                amB = joiners.paid;
            }
            payOut(amA, amB, account, p.cToken, p.jToken);
            /*        
            Deletes promise from account specific promises
            */
            bytes32 listId = sha256(abi.encodePacked(account));
            bytes32 index = sha256(abi.encodePacked(listId, id));
            deleteEntry(id, listId, index);
        }

        emit PromiseExecuted(account, id);
    }

    function _createPromise(
        address account,
        address cToken,
        uint112 cAmount,
        address jToken,
        uint112 jAmount,
        uint256 expiry
    ) internal {
        require(expiry > block.timestamp.add(10 minutes), "Expiry date is in the past");
        lastId += 1;
        promises[lastId] = PromData(
            account,
            cToken,
            cAmount,
            uint256(cAmount).div(2),
            false,
            jToken,
            jAmount,
            0,
            0,
            expiry
        );
        bytes32 listId = sha256(abi.encodePacked(cToken, jToken));
        bytes32 entry = sha256(abi.encodePacked(listId, lastId));
        addEntry(lastId, listId, entry);
        listId = sha256(abi.encodePacked(account));
        entry = sha256(abi.encodePacked(listId, lastId));
        addEntry(lastId, listId, entry);

        emit PromiseCreated(account, cToken, cAmount, jToken, jAmount, expiry);
    }

    function _joinPromise(
        uint256 id,
        address account,
        uint112 _amount
    ) internal {
        PromData memory p = promises[id];
        bytes32 jid = sha256(abi.encodePacked(id, account));
        uint256 leftOver = uint256(p.jAmount).sub((p.jDebt).mul(2).add(p.jPaid));
        require(p.expiry > block.timestamp, "Expiry date is in the past and can't be joined");
        require(_amount <= leftOver, "Amount too high for this promise");
        /*        
       Adding entries to two linked lists:
       firstly adding this account and info (paid, debt, executed) to the list of joiner info for this promise
       secondly adding this promise to a list of promises the account is involved with 
       */
        bytes32 listId = sha256(abi.encodePacked(id));
        bytes32 entry = sha256(abi.encodePacked(listId, account));
        addEntry(joinersLength[id], listId, entry);
        if (joiners[id][jid].paid == 0) {
            listId = sha256(abi.encodePacked(account));
            entry = sha256(abi.encodePacked(listId, id));
            addEntry(id, listId, entry);
        }
        uint112 amount = uint112(uint256(_amount).div(2));
        require(amount > 0, "Amount too small");
        promises[id].jDebt += amount;
        joiners[id][jid].debt += amount;
        joiners[id][jid].paid += amount;
        joinersLength[id]++;
        /*        
       if the maximum amount of tokens have joined the promise, this removes the promise from the joinable linked list 
       */
        if (leftOver == 0) {
            bytes32 listId = sha256(abi.encodePacked(promises[id].cToken, promises[id].jToken));
            bytes32 index = sha256(abi.encodePacked(listId, id));
            deleteEntry(id, listId, index);
        }
        emit PromiseJoined(account, id, amount);
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
        if (list[listId].id != id) {
            require(list[index].id == id, "incorrect index");
            if (list[index].next != "") {
                list[list[index].next].previous = list[index].previous;
            }
            if (list[index].previous != "") {
                list[list[index].previous].next = list[index].next;
                if (tail[listId] == index) {
                    tail[listId] = list[index].previous;
                }
            }
        } else {
            list[listId].id = list[list[listId].next].id;
            list[listId].next = list[list[listId].next].next;
        }
        length[listId] -= 1;
    }

    function payOut(
        uint256 amA,
        uint256 amB,
        address account,
        address assA,
        address assB
    ) internal {
        uint256 fA = amA.div(200);
        uint256 fB = amB.div(200);
        IERC20(assA).transfer(account, amA.sub(fA));
        IERC20(assB).transfer(account, amB.sub(fB));
        IERC20(assA).transfer(feeAddress, fA);
        IERC20(assB).transfer(feeAddress, fB);
    }

    /** Get Promise Arrays

       How to use: getPromises_Token_Amount(), getPromises_Time_Executed_Addr(), getPromises_owed()
       if you want promises specific to an account eg. a list of Promises 1 user is involved in.
       input the account and true for accountPairSwitch (Doesn't matter what you put for cToken and jToken)

       if you want promises specific to a pair eg. a list of Promises for ETH/DAI 
       input false for accountPairSwitch and input the two token addresses as cToken & jToken
       
       **/

    function joinablePromises(address _cToken, address _jToken)
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory cAmount,
            uint256[] memory jAmount,
            uint256[] memory expiry
        )
    {
        bytes32 listId = sha256(abi.encodePacked(_cToken, _jToken));
        uint256 _length = length[listId];

        id = new uint256[](_length);
        cAmount = new uint256[](_length);
        jAmount = new uint256[](_length);
        expiry = new uint256[](_length);

        uint256 i;
        bytes32 index = listId;
        PromData memory p;
        while (i < _length) {
            p = promises[id[i]];
            id[i] = list[index].id;
            cAmount[i] = uint256(p.cAmount).sub(shareCal(p.cAmount, p.jAmount, (p.jPaid).add(p.jDebt)));
            jAmount[i] = uint256(p.jAmount).sub((p.jPaid).add(p.jDebt));
            expiry[i] = p.expiry;
            index = list[index].next;
            i += 1;
        }
    }

    function accountPromises(address account)
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory debt,
            uint256[] memory receiving,
            uint256[] memory expiry,
            address[] memory tokens
        )
    {
        bytes32 listId = sha256(abi.encodePacked(account));
        uint256 _length = length[listId];

        id = new uint256[](_length);
        debt = new uint256[](_length);
        receiving = new uint256[](_length);
        expiry = new uint256[](_length);
        // tokens array is twice the length because it has 2 entries added every loop
        tokens = new address[](_length.mul(2));

        uint256 i;
        bytes32 index = listId;
        PromData memory p;
        Promjoiners memory j;
        while (i < _length) {
            id[i] = list[index].id;
            p = promises[id[i]];
            tokens[i > 0 ? i * 2 : 0] = p.cToken;
            tokens[i > 0 ? (i * 2) - 1 : 0] = p.jToken;
            if (p.creator == account) {
                debt[i] = p.cDebt;
                receiving[i] = p.jAmount;
            } else {
                bytes32 jid = sha256(abi.encodePacked(id[i], account));
                j = joiners[id[i]][jid];
                debt[i] = j.debt;
                receiving[i] = shareCal(p.cAmount, p.jAmount, (j.paid).add(j.debt));
            }
            expiry[i] = p.expiry;
            index = list[index].next;
            i += 1;
        }
    }

    function shareCal(
        uint112 a,
        uint112 b,
        uint256 c
    ) public view returns (uint256 z) {
        z = ShareCalculator.divMul(a, b, uint224(c));
    }
}
