// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {SafeMath} from "./Lib/SafeMath.sol";

import { ReentrancyGuard } from "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract PromiseCore {
    address public feeAddress;

    mapping(uint256 => PromData) public promises;
    mapping(uint256 => mapping(uint256 => JoinersInfo)) public joiners;
    mapping(uint256 => uint256) public joinersLength;

    mapping(bytes32 => LinkedList) list;
    mapping(bytes32 => bytes32) tail;
    mapping(bytes32 => uint256) length;

    uint256 public lastId;

    struct PromData {
        address creator;
        address cAsset;
        uint256 cAmount;
        uint256 cDebt;
        bool cExecuted;
        bytes32 joinersInfo;
        address jAsset;
        uint256 jAmount;
        uint256 jDebt;
        uint256 jPaidFull;
        uint256 expiry;
    }

    struct JoinersInfo {
        address joiner;
        uint256 paid;
        uint256 debt;
        bool joinerExecuted;
    }

    struct LinkedList {
        bytes32 next;
        uint256 id;
        bytes32 previous;
    }

    event PromiseCreated(address creator, address cAsset, uint cAmount, address jAsset, uint jAmount, uint expiry);
    event PromiseJoined(address addrB, uint256 id, uint256 amount);
    event PromiseCanceled(address executor, uint256 id);
    event PromiseExecuted(address executor, uint256 id);

    constructor(address _feeAddress) public {
        feeAddress = _feeAddress;
    }

    function createPromise(
        address account,        
        address cAsset,
        uint256 cAmount,        
        address jAsset,
        uint256 jAmount,
        uint256 expiry
    ) external nonReentrant {
        IERC20(assetA).transferFrom(msg.sender, address(this), cAmount.div(2));
        _createPromise(account, cAsset, cAmount, jAsset, jAmount, expiry);
    }

    function joinPromise(
        uint256 id,
        address account
        uint256 amount
    ) external nonReentrant {
        require(promise[id].creator != account, "Can't join your own promise")
        IERC20(promises[id].jAsset).transferFrom(msg.sender, address(this), amount);
        _joinPromise(id, account, amount);
    }

    function payPromise(uint256 id, address account) external nonReentrant {
        require(promises[id].addrB != address(0x0), "This promise hasn't been joined yet");
        require(promises[id].time >= block.timestamp, "This promise is no longer active");
        require(account == promises[id].addrA || account == promises[id].addrB, "This account is not involved in this promise");
        PromData memory promData = promises[id];
        IERC20 token;
        if (account == promData.addrA) {
            token = IERC20(promData.assetA);
            token.transferFrom(msg.sender, address(this), promData.amountA.div(2));
            promises[id].owedA = 0;
        } else if (account == promData.addrB) {
            token = IERC20(promData.assetB);
            token.transferFrom(msg.sender, address(this), promData.amountB.div(2));
            promises[id].owedB = 0;
        }
    }

    function cancelPromise(
        uint256 id
    ) external nonReentrant {
        require(msg.sender == promises[id].creator, "This account is not involved in this promise");
        require(promises[id].executed == false, "This promise has been executed");
        PromData memory promData = promises[id];
        /*      
        Calculate how much needs to be refunded
        this is only the capital which is not being utilised by the joiners. 
        No joiners means all capital added by the creator is refunded.
       */

        uint activeAmount = (promData.jDebt).mul(2).add(promData.jPaidFull)
        uint refund = (promData.cAmount).sub((promData.cAmount).div(promData.jAmount)).mul(actAmount);
        promises[id].cAmount = (promData.cAmount).sub(refund);
        promises[id].jAmount = activeAmount;
        /*      
        delete entries from 2 linked lists
        First, deletes from the relevant joinablePromise list so its not advertised to people anymore
        second, deletes from the account promises if nobody joined  
       */
        bytes32 listId = sha256(abi.encodePacked(promData.cAsset, promData.jAsset));
        bytes32 index = sha256(abi.encodePacked(listId, id));
        deleteEntry(id, listId, index);
        
        if (joinerLength[id] = 0) {
        listId = sha256(abi.encodePacked(msg.sender));
        index = sha256(abi.encodePacked(listId, id))
        deleteEntry(id, listId, index);      
        
        promises[id].cExecuted = true;
        }

        IERC20(promData.cAsset).transfer(promData.creator, refund);
        emit PromiseCanceled(msg.sender, id);
    }

        /*        
        executing a promise
        if you are the creator pId should be the id of the promise you are referencing and jId should be 0
        if you are a joiner, you need the pId and jId
       */
    function executePromise(
        uint256 pid,
        uint256 jid
    ) external nonReentrant {
        require(promises[id].expiry <= block.timestamp, "This promise has not expired yet");
        require(msg.sender == promises[pid].creator || joiners[pid][jid].joiner == msg.sender);            
        uint amA, amB;
        PromData memory promData = promises[id];
        if (msg.sender == promises[pid].creator) {
            require(promises[pid].executed == false)
            promises[id].executed = true;
            amA = (promData.cAmount).sub((promData.cAmount).div(promData.jAmount)).mul(actAmount)
            amB = (promData.jDebt).add(promData.jPaid)
            payOut(uint256 amA,uint256 amB,address a,address b,);
            bytes32 listId = sha256(abi.encodePacked(msg.sender));
            bytes32 index = sha256(abi.encodePacked(listId, id));
            deleteEntry(id, listId, index);

        } else {
            require(joiners[pid][jid].executed == false)
            joiners[pid][jid].executed = true;
            // creator gets Debt + paid + (promData.cAmount).sub((promData.cAmount).div(promData.jAmount)).mul(actAmount);
            payOut(uint256 amA,uint256 amB,address a,address b,);
            bytes32 listId = sha256(abi.encodePacked(msg.sender));
            bytes32 index = sha256(abi.encodePacked(listId, id));
            deleteEntry(id, listId, index);
            

        }


        emit PromiseExecuted(msg.sender, pid);
    }
    function _createPromise(
        address account,
        address cAsset,        
        uint256 cAmount,
        address jAsset,
        uint256 jAmount,
        uint256 expiry
    ) internal {
        require(expiry > block.timestamp.add(10 minutes), "Expiry date is in the past");
        lastId += 1;
        uint256 id = lastId;
        promises[id] = PromData(account, cAsset, cAmount, cAmount.div(2), false, "", jAsset, jAmount, 0, expiry);

        bytes32 listId = sha256(abi.encodePacked(cAsset, jAsset));
        bytes32 entry = sha256(abi.encodePacked(listId, id));
        addEntry(id, listId, entry);

        listId = sha256(abi.encodePacked(account));
        entry = sha256(abi.encodePacked(listId, id));
        addEntry(id, listId, entry);

        emit PromiseCreated(account, cAsset, cAmount, jAsset, jAmount, expiry);
    }


    function _joinPromise(
        uint256 id,
        address account,
        uint256 amount,
        bytes32 index
    ) internal {
        PromData memory promData = promises[id];
        require(promData.expiry > block.timestamp, "Expiry date is in the past and can't be joined");
        require(amount <= promData.jAmount.sub((promData.jDebt).mul(2).add(promData.jPaidFull)) , "Amount too high for this promise")
        promData.jDebt += amount;
        joiners[id][joinerLength[id]] = (account, amount, amount, false);

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
           bytes32 listId = sha256(abi.encodePacked(promises[id].assetA, promises[id].assetB));
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

    function getPairID(address assetA, address assetB) public view returns (bytes32) {
        return sha256(abi.encodePacked(assetA, assetB));
    }

    function payOut(
        uint256 amA,
        uint256 amB,
        address a,
        address b,
    ) internal {
        uint256 fA = amA.div(200);
        uint256 fB = amB.div(200);
        IERC20(assA).transfer(b, amA.sub(fA));
        IERC20(assB).transfer(a, amB.sub(fB));
        IERC20(assA).transfer(feeAddress, fA);
        IERC20(assB).transfer(feeAddress, fB);

    }

    /** Get Promise Arrays

       How to use: getPromises_Asset_Amount(), getPromises_Time_Executed_Addr(), getPromises_owed()
       if you want promises specific to an account eg. a list of Promises 1 user is involved in.
       input the account and true for accountPairSwitch (Doesn't matter what you put for assetA and assetB)

       if you want promises specific to a pair eg. a list of Promises for ETH/DAI 
       input false for accountPairSwitch and input the two token addresses as assetA & assetB
       
       **/

    function getPromises_Asset_Amount(
        address account,
        bool accountPairSwitch,
        address _assetA,
        address _assetB
    )
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory amountA,
            uint256[] memory amountB,
            address[] memory assetA,
            address[] memory assetB
        )
    {
        bytes32 listId;
        if (accountPairSwitch) {
            listId = sha256(abi.encodePacked(account));
        } else {
            listId = sha256(abi.encodePacked(_assetA, _assetB));
        }
        uint256 _length = length[listId];

        id = new uint256[](_length);
        amountA = new uint256[](_length);
        amountB = new uint256[](_length);
        assetA = new address[](_length);
        assetB = new address[](_length);

        uint256 i = 0;
        bytes32 index = listId;
        while (i < _length) {
            id[i] = list[index].id;
            amountA[i] = promises[id[i]].amountA;
            amountB[i] = promises[id[i]].amountB;
            assetA[i] = promises[id[i]].assetA;
            assetB[i] = promises[id[i]].assetB;
            index = list[index].next;
            i += 1;
        }
    }

    function getPromises_Time_Executed_Addr(
        address account,
        bool accountPairSwitch,
        address _assetA,
        address _assetB
    )
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory time,
            bool[] memory executed,
            address[] memory addrA,
            address[] memory addrB
        )
    {
        bytes32 listId;
        if (accountPairSwitch) {
            listId = sha256(abi.encodePacked(account));
        } else {
            listId = sha256(abi.encodePacked(_assetA, _assetB));
        }
        uint256 _length = length[listId];

        id = new uint256[](_length);
        time = new uint256[](_length);
        executed = new bool[](_length);
        addrA = new address[](_length);
        addrB = new address[](_length);

        uint256 i = 0;
        bytes32 index = listId;
        while (i < _length) {
            id[i] = list[index].id;
            time[i] = promises[id[i]].time;
            executed[i] = promises[id[i]].executed;
            addrA[i] = promises[id[i]].addrA;
            addrB[i] = promises[id[i]].addrB;
            index = list[index].next;
            i += 1;
        }
    }

    function getPromises_owed(
        address account,
        bool accountPairSwitch,
        address _assetA,
        address _assetB
    )
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory owedA,
            uint256[] memory owedB
        )
    {
        bytes32 listId;
        if (accountPairSwitch) {
            listId = sha256(abi.encodePacked(account));
        } else {
            listId = sha256(abi.encodePacked(_assetA, _assetB));
        }
        uint256 _length = length[listId];

        id = new uint256[](_length);
        owedA = new uint256[](_length);
        owedB = new uint256[](_length);

        uint256 i = 0;
        bytes32 index = listId;
        while (i < _length) {
            id[i] = list[index].id;
            owedA[i] = promises[id[i]].owedA;
            owedB[i] = promises[id[i]].owedB;
            index = list[index].next;
            i += 1;
        }
    }

    /** Single Promise Data **/

    function getPromiseData_Amount_Asset_Time_Executed(uint256 id)
        external
        view
        returns (
            uint256,
            address,
            uint256,
            address,
            uint256,
            bool
        )
    {
        PromData memory promData = promises[id];
        return (promData.amountA, promData.assetA, promData.amountB, promData.assetB, promData.time, promData.executed);
    }

    function getPromiseData_Addr(uint256 id)
        external
        view
        returns (
            address,
            address,
        )
    {
        PromData memory promData = promises[id];
        return (promData.addrA, promData.addrB);
    }

}
