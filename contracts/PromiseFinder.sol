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

    function joinablePromises(
        address _creatorToken,
        address _joinerToken,
        uint256 preferedDateWithinMonth,
        uint112 preferedCreatorAmount,
        uint112 preferedJoinerAmount
    )
        public
        view
        returns (
            uint256[] memory id,
            uint256[] memory creatorAmount,
            uint256[] memory joinerAmount,
            uint256[] memory expirationTimestamp
        )
    {
        (id, creatorAmount, joinerAmount, expirationTimestamp) = _joinablePromises(
            keccak256(
                abi.encodePacked(
                    _creatorToken,
                    _joinerToken,
                    numberOfTimeIntervalsSinceDeployed(preferedDateWithinMonth),
                    integarNumberOfBytes(preferedCreatorAmount),
                    integarNumberOfBytes(preferedJoinerAmount)
                )
            )
        );
    }

    function _joinablePromises(bytes32 _listId)
        public
        view
        returns (
            uint256[] memory id,
            uint256[] memory creatorAmount,
            uint256[] memory joinerAmount,
            uint256[] memory expirationTimestamp
        )
    {
        bytes32 listId = _listId;
        uint256 _length = promiseCore.length(listId);

        id = new uint256[](_length);
        creatorAmount = new uint256[](_length);
        joinerAmount = new uint256[](_length);
        expirationTimestamp = new uint256[](_length);

        uint256 i;
        bytes32 index = listId;
        PromData memory p;
        while (i < _length) {
            (index, id[i], ) = promiseCore.list(index);
            (
                ,
                ,
                p.creatorAmount,
                ,
                ,
                ,
                p.joinerAmount,
                p.joinerDebt,
                p.joinerPaidFull,
                p.expirationTimestamp
            ) = promiseCore.promises(id[i]);
            creatorAmount[i] =
                uint256(p.creatorAmount) -
                (promiseCore.divMul(p.creatorAmount, p.joinerAmount, (p.joinerPaidFull) + (p.joinerDebt * 2)));
            joinerAmount[i] = uint256(p.joinerAmount) - ((p.joinerPaidFull) + (p.joinerDebt * 2));
            expirationTimestamp[i] = p.expirationTimestamp;
            i++;
        }
    }

    function _joinablePromisesRaw(bytes32[] memory _listId, uint256 numberOfPromises)
        public
        view
        returns (
            uint256[] memory id,
            uint256[] memory creatorAmount,
            uint256[] memory joinerAmount,
            uint256[] memory expirationTimestamp
        )
    {
        id = new uint256[](numberOfPromises);
        creatorAmount = new uint256[](numberOfPromises);
        joinerAmount = new uint256[](numberOfPromises);
        expirationTimestamp = new uint256[](numberOfPromises);

        uint256 _length;
        uint256 i;
        uint256 j;
        uint256 q;
        while (j < _listId.length && i < numberOfPromises) {
            _length = promiseCore.length(_listId[j]);
            bytes32 index = _listId[j];
            PromData memory p;
            while (q < _length) {
                (index, id[i], ) = promiseCore.list(index);
                (
                    ,
                    ,
                    p.creatorAmount,
                    ,
                    ,
                    ,
                    p.joinerAmount,
                    p.joinerDebt,
                    p.joinerPaidFull,
                    p.expirationTimestamp
                ) = promiseCore.promises(id[i]);
                creatorAmount[i] =
                    uint256(p.creatorAmount) -
                    (promiseCore.divMul(p.creatorAmount, p.joinerAmount, (p.joinerPaidFull) + (p.joinerDebt * 2)));
                joinerAmount[i] = uint256(p.joinerAmount) - ((p.joinerPaidFull) + (p.joinerDebt * 2));
                expirationTimestamp[i] = p.expirationTimestamp;
                q++;
                i++;
            }
            q = 0;
            j++;
        }
        uint256 excess = numberOfPromises - i;
        assembly {
            mstore(id, sub(mload(id), excess))
            mstore(creatorAmount, sub(mload(creatorAmount), excess))
            mstore(joinerAmount, sub(mload(joinerAmount), excess))
            mstore(expirationTimestamp, sub(mload(expirationTimestamp), excess))
        }
    }

    function getPopulatedJoinableTimeIntervals(
        address creatorToken,
        address joinerToken,
        uint256 minExpiryDate,
        uint256 maxExpiryDate
    )
        public
        view
        returns (uint256[] memory expirationTimestampWithinInterval, uint256[] memory numOfPromisesInTimeInterval)
    {
        uint256 timeInterval = promiseCore.joinableListIdTimeInterval();
        uint256 numberOfTimeIntervals = (maxExpiryDate - minExpiryDate) / timeInterval;
        require(numberOfTimeIntervals <= 200, "Range too wide");
        expirationTimestampWithinInterval = new uint256[](numberOfTimeIntervals);
        numOfPromisesInTimeInterval = new uint256[](numberOfTimeIntervals);
        uint256 expirationTimestamp = minExpiryDate;
        uint256 i;
        uint256 _numberOfPromisesInTimeInterval;
        while (expirationTimestamp < maxExpiryDate - timeInterval) {
            _numberOfPromisesInTimeInterval = promiseCore.numberOfPromisesInTimeInterval(
                keccak256(
                    abi.encodePacked(creatorToken, joinerToken, numberOfTimeIntervalsSinceDeployed(expirationTimestamp))
                )
            );
            if (_numberOfPromisesInTimeInterval > 0) {
                expirationTimestampWithinInterval[i] = expirationTimestamp;
                numOfPromisesInTimeInterval[i] = _numberOfPromisesInTimeInterval;
                i++;
            }
            expirationTimestamp += timeInterval;
        }
        uint256 excess = numberOfTimeIntervals - i;
        assembly {
            mstore(expirationTimestampWithinInterval, sub(mload(expirationTimestampWithinInterval), excess))
            mstore(numOfPromisesInTimeInterval, sub(mload(numOfPromisesInTimeInterval), excess))
        }
    }

    function getPopulatedJoinableListIds(
        address creatorToken,
        address joinerToken,
        uint256[] memory expirationTimestampsWithinIntervals,
        uint8 numberOfListIds
    ) public view returns (bytes32[] memory listIds, uint256[] memory lengths) {
        listIds = new bytes32[](numberOfListIds);
        lengths = new uint256[](numberOfListIds);
        uint256 numberOfBytesInCreatorAmount;
        uint256 numberOfBytesInJoinerAmount = 14;
        bytes32 currentListId;
        uint256 i;
        uint256 x;
        while (x < expirationTimestampsWithinIntervals.length && i < numberOfListIds) {
            while (numberOfBytesInCreatorAmount < 14 && i < numberOfListIds) {
                while (numberOfBytesInJoinerAmount != 0 && i < numberOfListIds) {
                    currentListId = keccak256(
                        abi.encodePacked(
                            creatorToken,
                            joinerToken,
                            numberOfTimeIntervalsSinceDeployed(expirationTimestampsWithinIntervals[x]),
                            numberOfBytesInCreatorAmount,
                            numberOfBytesInJoinerAmount
                        )
                    );
                    if (promiseCore.length(currentListId) > 0) {
                        listIds[i] = currentListId;
                        lengths[i] = promiseCore.length(currentListId);
                        i++;
                    }

                    numberOfBytesInJoinerAmount--;
                }
                numberOfBytesInJoinerAmount = 14;
                numberOfBytesInCreatorAmount++;
            }
            numberOfBytesInCreatorAmount = 0;
            numberOfBytesInJoinerAmount = 14;
            x++;
        }
        uint256 excess = numberOfListIds - i;
        assembly {
            mstore(listIds, sub(mload(listIds), excess))
            mstore(lengths, sub(mload(lengths), excess))
        }
    }

    function numberOfTimeIntervalsSinceDeployed(uint256 expirationTimestamp) internal view returns (uint256 result) {
        result = (expirationTimestamp - promiseCore.startBlockTime()) / promiseCore.joinableListIdTimeInterval();
    }

    function integarNumberOfBytes(uint112 number) internal pure returns (uint256 _length) {
        while (number != 0) {
            number >>= 8;
            _length++;
        }
    }
}
