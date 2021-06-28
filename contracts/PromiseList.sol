// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.4.21 <0.8.0;

import {SafeMath} from "./lib/math/SafeMath.sol";

contract PromiseList {
    using SafeMath for uint256;
    mapping(bytes32 => LinkedList) public list;
    mapping(bytes32 => bytes32) public tail;
    mapping(bytes32 => uint256) public length;
    mapping(bytes32 => uint256) public numberOfPromisesInTimeInterval;
    uint256 public joinableListIdTimeInterval = 1 days;
    uint256 public startBlockTime;

    struct LinkedList {
        bytes32 next;
        uint256 id;
        bytes32 previous;
    }

    constructor() public {
        startBlockTime = block.timestamp;
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
        bytes32 listId = keccak256(abi.encodePacked(account));
        bytes32 index = keccak256(abi.encodePacked(listId, id));
        deleteEntry(id, listId, index);
    }

    function addToAccountList(uint256 id, address account) internal {
        bytes32 listId = keccak256(abi.encodePacked(account));
        bytes32 entry = keccak256(abi.encodePacked(listId, id));
        addEntry(id, listId, entry);
    }

    function deleteFromJoinableList(
        uint256 id,
        address creatorToken,
        address joinerToken,
        uint256 expirationTimestamp,
        uint112 creatorAmount,
        uint112 joinerAmount
    ) internal {
        numberOfPromisesInTimeInterval[
            keccak256(abi.encodePacked(creatorToken, joinerToken, timeIntervalSinceDeployed(expirationTimestamp)))
        ] -= creatorAmount;
        bytes32 listId =
            keccak256(
                abi.encodePacked(
                    creatorToken,
                    joinerToken,
                    timeIntervalSinceDeployed(expirationTimestamp),
                    integarBytes(creatorAmount),
                    integarBytes(joinerAmount)
                )
            );
        bytes32 index = keccak256(abi.encodePacked(listId, id));
        deleteEntry(id, listId, index);
    }

    function addToJoinableList(
        address creatorToken,
        address joinerToken,
        uint256 expirationTimestamp,
        uint112 creatorAmount,
        uint112 joinerAmount,
        uint256 lastId
    ) internal {
        numberOfPromisesInTimeInterval[
            keccak256(abi.encodePacked(creatorToken, joinerToken, timeIntervalSinceDeployed(expirationTimestamp)))
        ] += creatorAmount;
        bytes32 listId =
            keccak256(
                abi.encodePacked(
                    creatorToken,
                    joinerToken,
                    timeIntervalSinceDeployed(expirationTimestamp),
                    integarBytes(creatorAmount),
                    integarBytes(joinerAmount)
                )
            );
        bytes32 entry = keccak256(abi.encodePacked(listId, lastId));
        addEntry(lastId, listId, entry);
    }

    function timeIntervalSinceDeployed(uint256 expirationTimestamp) internal view returns (uint256 result) {
        result = (expirationTimestamp.sub(startBlockTime)).div(joinableListIdTimeInterval);
    }

    function integarBytes(uint112 number) internal pure returns (uint256 _length) {
        while (number != 0) {
            number >>= 8;
            _length++;
        }
    }
}
