// SPDX-License-Identifier: MIT

pragma solidity >=0.4.21 <0.8.4;

interface IPromiseFinder {
    function accountPromises(address account)
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory outstandingDebt,
            uint256[] memory receiving,
            uint256[] memory expirationTimestamp,
            address[] memory tokens
        );

    function joinablePromises(
        address _creatorToken,
        address _joinerToken,
        uint256 preferedDateWithinMonth,
        uint112 preferedCreatorAmount,
        uint112 preferedJoinerAmount
    )
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory creatorAmount,
            uint256[] memory joinerAmount,
            uint256[] memory expirationTimestamp
        );

    function _joinablePromises(bytes32 _listId)
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory creatorAmount,
            uint256[] memory joinerAmount,
            uint256[] memory expirationTimestamp
        );

    function getPopulatedJoinableLists(
        address creatorToken,
        address joinerToken,
        uint256 minExpiryDate,
        uint256 maxExpiryDate
    ) external view returns (bytes32[] memory listIds, uint256[] memory lengths);
}
