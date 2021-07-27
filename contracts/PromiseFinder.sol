pragma solidity >=0.4.21 <0.8.0;

import {PromiseCore} from "./PromiseCore.sol";

contract PromiseFinder {
    PromiseCore public promiseCore;

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

    constructor(PromiseCore _promiseCore) public {
        promiseCore = _promiseCore;
    }

    function accountPromises(address account)
        public
        view
        returns (
            uint256[] memory id,
            uint256[] memory outstandingDebt,
            uint256[] memory receiving,
            uint256[] memory expirationTimestamp,
            address[] memory tokens
        )
    {
        bytes32 listId = keccak256(abi.encodePacked(account));
        uint256 _length = promiseCore.length(listId);

        id = new uint256[](_length);
        outstandingDebt = new uint256[](_length);
        receiving = new uint256[](_length);
        expirationTimestamp = new uint256[](_length);
        // tokens array is twice the length because it has 2 entries added every loop
        tokens = new address[](_length * 2);

        uint256 i;
        bytes32 index = listId;
        while (i < _length) {
            (index, id[i], ) = promiseCore.list(index);
            (
                outstandingDebt[i],
                receiving[i],
                tokens[i > 0 ? i * 2 : 0],
                tokens[i > 0 ? (i * 2) + 1 : 1],
                expirationTimestamp[i]
            ) = _accountPromises(id[i], account);
            i++;
        }
    }

    function _accountPromises(uint256 id, address account)
        public
        view
        returns (
            uint256 outstandingDebt,
            uint256 receiving,
            address creatorToken,
            address joinerToken,
            uint256 expirationTimestamp
        )
    {
        PromData memory p;
        Promjoiners memory j;
        (p.creator, , , , , , , , , ) = promiseCore.promises(id);
        if (p.creator == account) {
            (
                ,
                p.creatorToken,
                ,
                p.creatorDebt,
                ,
                p.joinerToken,
                ,
                p.joinerDebt,
                p.joinerPaidFull,
                p.expirationTimestamp
            ) = promiseCore.promises(id);
            outstandingDebt = p.creatorDebt;
            receiving = p.joinerDebt + p.joinerPaidFull;
            creatorToken = p.creatorToken;
            joinerToken = p.joinerToken;
            expirationTimestamp = p.expirationTimestamp;
        } else {
            bytes32 joinerId = keccak256(abi.encodePacked(id, account));
            (j.amountPaid, j.outstandingDebt, j.hasExecuted) = promiseCore.joiners(id, joinerId);
            (
                ,
                p.creatorToken,
                p.creatorAmount,
                ,
                ,
                p.joinerToken,
                p.joinerAmount,
                ,
                ,
                p.expirationTimestamp
            ) = promiseCore.promises(id);
            outstandingDebt = j.outstandingDebt;
            receiving = promiseCore.divMul(p.creatorAmount, p.joinerAmount, j.amountPaid + j.outstandingDebt);
            creatorToken = p.joinerToken;
            joinerToken = p.creatorToken;
            expirationTimestamp = p.expirationTimestamp;
        }
    }
}
