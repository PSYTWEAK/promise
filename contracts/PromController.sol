// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {UQ112x112} from "./Lib/UQ112x112.sol";

contract PromController {
    address public fspl;

    mapping(uint256 => PromData) promises;

    mapping(bytes32 => LinkedList) list;
    mapping(bytes32 => bytes32) tail;
    mapping(bytes32 => uint256) length;

    uint256 public lastId;

    struct LinkedList {
        bytes32 next;
        uint256 id;
        bytes32 previous;
    }

    struct PromData {
        /** ---------------------
         a is the creator
         b is the joiner
         time is the minimum date it can be executed
        --------------------- **/
        address addrA;
        uint256 amountA;
        address assetA;
        uint256 owedA;
        address addrB;
        uint256 amountB;
        address assetB;
        uint256 owedB;
        uint256 time;
        bool executed;
    }
    event PromiseCreated(address addrA, uint256 amountA, address assetA, uint256 amountB, address assetB, uint256 time);
    event PromiseJoined(address addrB, uint256 id);
    event PromiseCanceled(address executor, uint256 id);
    event PromiseExecuted(address executor, uint256 id);

    constructor(address _fspl) public {
        fspl = _fspl;
    }

    function createPromise(
        address account,
        uint256 amountA,
        address assetA,
        uint256 amountB,
        address assetB,
        uint256 time
    ) external {
        IERC20 token = IERC20(assetA);
        token.transferFrom(msg.sender, address(this), amountA / 2);
        _createPromise(account, amountA, assetA, amountB, assetB, time);
    }

    function joinPromise(
        uint256 id,
        address account,
        bytes32 index
    ) external {
        IERC20 token = IERC20(promises[id].assetB);
        token.transferFrom(msg.sender, address(this), promises[id].amountB / 2);
        _joinPromise(id, account, index);
    }

    function payPromise(uint256 id, address account) external {
        require(promises[id].addrB != address(0x0), "This promise hasn't been joined yet");
        require(promises[id].time >= block.timestamp, "This promise is no longer active");
        require(account == promises[id].addrA || account == promises[id].addrB, "This account is not involved in this promise");
        PromData memory promData = promises[id];
        IERC20 token;
        if (account == promData.addrA) {
            token = IERC20(promData.assetA);
            token.transferFrom(msg.sender, address(this), promData.amountA / 2);
            promises[id].owedA = 0;
        } else if (account == promData.addrB) {
            token = IERC20(promData.assetB);
            token.transferFrom(msg.sender, address(this), promData.amountB / 2);
            promises[id].owedB = 0;
        }
    }

    function cancelPromise(
        uint256 id,
        bytes32 accountIndex,
        bytes32 joinableIndex
    ) external {
        require(msg.sender == promises[id].addrA, "This account is not involved in this promise");
        require(promises[id].addrB == address(0x0), "Promise cant be canceled once active");
        require(promises[id].executed == false, "This promise has been executed");
        IERC20 tokenA = IERC20(promises[id].assetA);
        tokenA.transfer(promises[id].addrA, promises[id].amountA / 2);

        bytes32 listId = sha256(abi.encodePacked(promises[id].assetA, promises[id].assetB));
        deleteEntry(id, listId, joinableIndex);
        listId = sha256(abi.encodePacked(msg.sender));
        deleteEntry(id, listId, accountIndex);

        promises[id].executed = true;
        emit PromiseCanceled(msg.sender, id);
    }

    function executePromise(
        uint256 id,
        bytes32 creatorAccIndex,
        bytes32 joinerAccIndex
    ) external {
        require(promises[id].time <= block.timestamp, "This promise has not expired yet");
        require(promises[id].executed == false, "This promise has been executed");
        PromData memory promData = promises[id];

        payOut(promData.amountA, promData.amountB, promData.owedA, promData.owedB, promData.addrA, promData.addrB, promData.assetA, promData.assetB);

        promises[id].executed = true;

        bytes32 listId = sha256(abi.encodePacked(promises[id].addrA));
        deleteEntry(id, listId, creatorAccIndex);
        listId = sha256(abi.encodePacked(promises[id].addrB));
        deleteEntry(id, listId, joinerAccIndex);

        emit PromiseExecuted(msg.sender, id);
    }

    function _createPromise(
        address account,
        uint256 amountA,
        address assetA,
        uint256 amountB,
        address assetB,
        uint256 time
    ) internal {
        require(time > block.timestamp + 10 minutes, "Expiry date is in the past");
        lastId += 1;
        uint256 id = lastId;
        promises[id] = PromData(account, amountA, assetA, amountA / 2, address(0x0), amountB, assetB, amountB, time, false);

        bytes32 listId = sha256(abi.encodePacked(assetA, assetB));
        bytes32 entry = sha256(abi.encodePacked(listId, id));
        addEntry(id, listId, entry);

        listId = sha256(abi.encodePacked(account));
        entry = sha256(abi.encodePacked(listId, id));
        addEntry(id, listId, entry);

        emit PromiseCreated(account, amountA, assetA, amountB, assetB, time);
    }

    function _joinPromise(
        uint256 id,
        address account,
        bytes32 index
    ) internal {
        require(promises[id].time > block.timestamp, "Expiry date is in the past and can't be joined");
        require(promises[id].addrB == address(0x0), "This promise has already been joined");
        require(account != promises[id].addrB, "This promise has already been joined");
        promises[id].owedB = promises[id].amountB / 2;
        promises[id].addrB = account;
        bytes32 listId = sha256(abi.encodePacked(promises[id].assetA, promises[id].assetB));

        deleteEntry(id, listId, index);

        listId = sha256(abi.encodePacked(account));
        bytes32 entry = sha256(abi.encodePacked(listId, id));
        addEntry(id, listId, entry);

        emit PromiseJoined(account, id);
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

    function getIndexAccount(uint256 id, address account) public view returns (bytes32) {
        bytes32 index = sha256(abi.encodePacked(account));
        while (id != list[index].id) {
            index = list[index].next;
        }
        return index;
    }

    function getIndexJoinable(uint256 id) public view returns (bytes32) {
        bytes32 index = sha256(abi.encodePacked(promises[id].assetA, promises[id].assetB));
        while (id != list[index].id) {
            index = list[index].next;
        }
        return index;
    }

    function payOut(
        uint256 amA,
        uint256 amB,
        uint256 oweA,
        uint256 oweB,
        address a,
        address b,
        address assA,
        address assB
    ) internal {
        uint256 fA = UQ112x112.uqdiv(uint224(amA), 300);
        uint256 fB = UQ112x112.uqdiv(uint224(amB), 300);

        if (oweA == 0 && oweB == 0) {
            IERC20(assA).transfer(b, amA - fA);
            IERC20(assB).transfer(a, amB - fB);
            IERC20(assA).transfer(fspl, fA);
            IERC20(assB).transfer(fspl, fB);
        } else if (oweA == 0 && oweB > 0) {
             IERC20(assA).transfer(a, amA - fA);
            IERC20(assB).transfer(a, amB / 2 - fB);
             IERC20(assA).transfer(fspl, fA);
           IERC20(assB).transfer(fspl, fB);
        } else if (oweB == 0 && oweA > 0) {
             IERC20(assA).transfer(b, amA / 2 - fA);
            IERC20(assB).transfer(b, amB - fB);
             IERC20(assA).transfer(fspl, fA);
            IERC20(assB).transfer(fspl, fB);
        } else {
             IERC20(assA).transfer(a, amA / 2);
            IERC20(assB).transfer(b, amB / 2);
        }
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
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            address[] memory,
            address[] memory
        )
    {
        bytes32 listId;
        if (accountPairSwitch) {
            listId = sha256(abi.encodePacked(account));
        } else {
            listId = sha256(abi.encodePacked(_assetA, _assetB));
        }
        uint256 _length = length[listId];

        uint256[] memory id = new uint256[](_length);

        uint256[] memory amountA = new uint256[](_length);

        uint256[] memory amountB = new uint256[](_length);

        address[] memory assetA = new address[](_length);

        address[] memory assetB = new address[](_length);

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

        return (id, amountA, amountB, assetA, assetB);
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
            uint256[] memory,
            uint256[] memory,
            bool[] memory,
            address[] memory,
            address[] memory
        )
    {
        bytes32 listId;
        if (accountPairSwitch) {
            listId = sha256(abi.encodePacked(account));
        } else {
            listId = sha256(abi.encodePacked(_assetA, _assetB));
        }
        uint256 _length = length[listId];

        uint256[] memory id = new uint256[](_length);

        uint256[] memory time = new uint256[](_length);

        bool[] memory executed = new bool[](_length);

        address[] memory addrA = new address[](_length);

        address[] memory addrB = new address[](_length);

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

        return (id, time, executed, addrA, addrB);
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
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        bytes32 listId;
        if (accountPairSwitch) {
            listId = sha256(abi.encodePacked(account));
        } else {
            listId = sha256(abi.encodePacked(_assetA, _assetB));
        }
        uint256 _length = length[listId];

        uint256[] memory id = new uint256[](_length);

        uint256[] memory owedA = new uint256[](_length);

        uint256[] memory owedB = new uint256[](_length);

        uint256 i = 0;
        bytes32 index = listId;
        while (i < _length) {
            id[i] = list[index].id;
            owedA[i] = promises[id[i]].owedA;
            owedB[i] = promises[id[i]].owedB;
            index = list[index].next;
            i += 1;
        }

        return (id, owedA, owedB);
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

}
