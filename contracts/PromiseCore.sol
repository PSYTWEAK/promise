// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {SafeMath} from "./Lib/SafeMath.sol";
import {ReentrancyGuard} from "./Lib/ReentrancyGuard.sol";
import {UQ112x112} from "./Lib/UQ112x112.sol";

contract PromiseCore {
    using SafeMath for uint256;
    using UQ112x112 for uint256;

    address public feeAddress;

    mapping(uint256 => PromData) public promises;
    mapping(uint256 => mapping(bytes32 => Promjoiners)) public joiners;
    mapping(uint256 => uint256) public joinersLength;

    mapping(bytes32 => LinkedList) list;
    mapping(bytes32 => bytes32) tail;
    mapping(bytes32 => uint256) length;

    uint256 public lastId;

    struct PromData {
        address creator;
        address cToken;
        uint256 cAmount;
        uint256 cDebt;
        bool cExecuted;
        /*  
        Not needed    
        bytes32 promjoiners; 
        */
        address jToken;
        uint256 jAmount;
        uint256 jDebt;
        uint256 jPaidFull;
        uint256 expiry;
    }

    struct Promjoiners {
        uint256 paid;
        uint256 debt;
        bool joinerExecuted;
    }

    struct LinkedList {
        bytes32 next;
        uint256 id;
        bytes32 previous;
    }

    event PromiseCreated(address creator, address cToken, uint cAmount, address jToken, uint jAmount, uint expiry);
    event PromiseJoined(address addrB, uint256 id, uint256 amount);
    event PromiseCanceled(address executor, uint256 id);
    event PromiseExecuted(address executor, uint256 id);

    constructor(address _feeAddress) public {
        feeAddress = _feeAddress;
    }

    function createPromise(
        address account,        
        address cToken,
        uint256 cAmount,        
        address jToken,
        uint256 jAmount,
        uint256 expiry
    ) external nonReentrant {
        IERC20(cToken).transferFrom(msg.sender, address(this), cAmount.div(2));
        _createPromise(account, cToken, cAmount, jToken, jAmount, expiry);
    }

    function joinPromise(
        uint256 id,
        address account
        uint256 amount
    ) external nonReentrant {
        require(promise[id].creator != account, "Can't join your own promise")
        IERC20(promises[id].jToken).transferFrom(msg.sender, address(this), amount);
        _joinPromise(id, account, amount);
    }

    function payPromise(uint256 id, address account) external nonReentrant {
        require(promises[id].expiry <= block.timestamp, "This promise has not expired yet");
        require(account == promises[id].creator || joiners[id][jid].joiner == account, "Account is not in this promise");            
        if (account == promises[id].creator) {
            IERC20(promises[id].cToken).transferFrom(msg.sender, address(this), promises[id].cDebt);
            promises[id].cDebt = 0;
        } else { 
            bytes32 jid = sha256(abi.encodePacked(id, account));
            IERC20(promises[id].jToken).transferFrom(msg.sender, address(this), joiners[id][jid]);
            joiners[id][jid] = joiners[id][jid].sub(joiners.debt);
            promises[id].jDebt = (promises[id].jDebt).sub(joiners.debt);
        }
    }

    function closePendingPromiseAmount(
        uint256 id
    ) external nonReentrant {
        require(msg.sender == promises[id].creator, "Only the creator can close");
        require(promises[id].executed == false, "This promise has been executed");
        PromData memory promData = promises[id];
        /*      
        Calculate how much needs to be refunded
        this is only the capital which is not being utilised by the joiners. 
        No joiners means all capital added by the creator is refunded.
       */
        uint activeAmount = (promData.jDebt).mul(2).add(promData.jPaidFull)
        uint refund = (promData.cAmount).sub(promData.cDebt).sub((promData.cAmount).div(promData.jAmount).mul(actAmount);)
        promises[id].cAmount = (promData.cAmount).sub(refund);
        promises[id].jAmount = activeAmount;
        /*      
        delete entries from 2 linked lists
        First, deletes from the relevant joinablePromise list so its not advertised to people anymore
        second, deletes from the account promises if nobody joined 
       */
        bytes32 listId = sha256(abi.encodePacked(promData.cToken, promData.jToken));
        bytes32 index = sha256(abi.encodePacked(listId, id));
        deleteEntry(id, listId, index);
        
        if (joinerLength[id] = 0) {
        listId = sha256(abi.encodePacked(msg.sender));
        index = sha256(abi.encodePacked(listId, id))
        deleteEntry(id, listId, index);      
        promises[id].cExecuted = true;
        }
        IERC20(promData.cToken).transfer(promData.creator, refund);
        emit PromiseCanceled(msg.sender, id);
    }

    /*        
        executing a promise
        if you are the creator id should be the id of the promise you are referencing and jId should be 0
        if you are a joiner, you need the promise id (id) and your own joiner Id (jid)
        Checks whether you are the creator or join and then gives you the required payout.
       */
    function executePromise(
        uint256 id,
        addresss account,
    ) external nonReentrant {
        require(promises[id].expiry <= block.timestamp, "This promise has not expired yet");      
        uint amA, amB;
        PromData memory promData = promises[id];
        if (account == promises[id].creator) {
            require(promises[id].cExecuted == false, "already executed");
            require(promises[id].cDebt == 0, "Creator didn't go through with the promise");
            promises[id].executed = true;
            amA = (promData.cAmount).sub((promData.cAmount).div(promData.jAmount)).mul(actAmount)
            amB = (promData.jDebt).add(promData.jPaid)
            payOut(amA,amB, account, promData.cToken, promData.jToken);
            bytes32 listId = sha256(abi.encodePacked(account));
            bytes32 index = sha256(abi.encodePacked(listId, id));
            deleteEntry(id, listId, index);

        } else {
            bytes32 jid = sha256(abi.encodePacked(id, account));
            require(joiners[id][jid].executed == false, "already executed");
            require(joiners[id][jid].debt == 0, "Joiner didn't go through with the promise");
            joiners[id][jid].executed = true;
            Promjoiners memory joiners = joiners[id][jid];
            amA = ((promData.cAmount).sub(promData.cDebt)).div(promData.jAmount).mul(joiners.paid);
            amB = 0;
            if (promData.cDebt > 0) {
                amB = joiners.paid;
            }
            payOut(amA,amB, account, promData.cToken, promData.jToken);
            /*        
            Deletes promise from account specific promises
            */
            bytes32 listId = sha256(abi.encodePacked(account));
            bytes32 entry = sha256(abi.encodePacked(listId, id));
            deleteEntry(id, listId, index);
        }


        emit PromiseExecuted(account, id);
    }
    function _createPromise(
        address account,
        address cToken,        
        uint256 cAmount,
        address jToken,
        uint256 jAmount,
        uint256 expiry
    ) internal {
        require(expiry > block.timestamp.add(10 minutes), "Expiry date is in the past");
        lastId += 1;
        promises[lastId] = PromData(account, cToken, cAmount, cAmount.div(2), false, "", jToken, jAmount, 0, expiry);
        bytes32 listId = sha256(abi.encodePacked(cToken, jToken));
        bytes32 entry = sha256(abi.encodePacked(listId, id));
        addEntry(id, listId, entry);
        listId = sha256(abi.encodePacked(account));
        entry = sha256(abi.encodePacked(listId, id));
        addEntry(id, listId, entry);

        emit PromiseCreated(account, cToken, cAmount, jToken, jAmount, expiry);
    }


    function _joinPromise(
        uint256 id,
        address account,
        uint256 amount,
    ) internal {
        PromData memory promData = promises[id];
        require(promData.expiry > block.timestamp, "Expiry date is in the past and can't be joined");
        require(amount <= promData.jAmount.sub((promData.jDebt).mul(2).add(promData.jPaidFull)) , "Amount too high for this promise")
        promises[id].jDebt += amount;
        joinersLength[id]++;
        bytes32 jid = sha256(abi.encodePacked(id, account));
        joiners[id][jid] = (amount, amount, false);
       /*        
       Adding entries to two linked lists:
       firstly adding this promise to a list of promises the account is involved with
       secondly adding this account and info (paid, debt, executed) to the list of joiner info for this promise
       */
        bytes32 listId = sha256(abi.encodePacked(account));
        bytes32 entry = sha256(abi.encodePacked(listId, id));
        addEntry(id, listId, entry);
        listId = sha256(abi.encodePacked(id))
        entry = sha256(abi.encodePacked(listId, account));
        addEntry(joinersLength[id], listId, entry);
       /*        
       if the maximum amount of tokens have joined the promise, this removes the promise from the joinable linked list 
       */
        if (promData.jAmount.sub((promData.jDebt).mul(2).add(promData.jPaidFull)) == 0) {
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
        require(list[index].id == id, "incorrect index");
        list[list[index].previous].next = list[index].next;
        list[list[index].next].previous = list[index].previous;
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
        IERC20(assA).transfer(b, amA.sub(fA));
        IERC20(assB).transfer(a, amB.sub(fB));
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

    function joinablePromises(
        address _cToken,
        address _jToken
    )
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

        uint256 i
        bytes32 index = listId;
        PromData memory p;
        while (i < _length) {
            p = promises[id];
            id[i] = list[index].id;
            cAmount[i] = (p[id[i]].cAmount).sub(uqdiv(p[id[i]].cAmount,p[id[i]].jAmount).mul((p[id[i]].jPaid).add(p[id[i]].jDebt)));;            
            jAmount[i] = (p[id[i]].jAmount).sub((p[id[i]].jPaid).add(p[id[i]].jDebt));
            expiry[i] = p[id[i]].expiry;
            index = list[index].next;
            i += 1;
        }
    }

        function accountPromises(
        address account,
    )
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory jid,
            uint256[] memory debt,         
            uint256[] memory receiving,
            uint256[] memory expiry
        )
    {
        bytes32 listId = sha256(abi.encodePacked(account));
        uint256 _length = length[listId];

        id = new uint256[](_length);
        jid = new uint256[](_length);        
        debt = new uint256[](_length);
        receiving = new uint256[](_length);
        expiry = new uint256[](_length);

        uint256 i
        bytes32 index = listId;
        PromData memory p;
        while (i < _length) {
            p = promises[id];
            id[i] = list[index].id;
            if(p[id[i]].creator == account) {
            debt[i] = p[id[i]].cDebt;          
            receiving[i] = p[id[i]].jAmount;
            expiry[i] = p[id[i]].expiry;
            jid[i] = 0;
            } else {
            
            debt[i] =        
            receiving[i] = 
            expiry[i] = 
            }
            index = list[index].next;
            i += 1;
        }
    }

    function findJid(address account, uint id) internal view returns (uint) {
        address _account;
        uint i;
        while (_account != account) {
            joiners[id][i]

        }


    }
    



}
