// SPDX-License-Identifier: MIT

pragma solidity >=0.4.21 <0.8.4;

interface IPromiseCore {
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

    function createPromise(
        address account,
        address cToken,
        uint112 cAmount,
        address jToken,
        uint112 jAmount,
        uint256 expiry
    ) external;

    function joinPromise(
        uint256 id,
        address account,
        uint112 _amount
    ) external;

    function payPromise(uint256 id, address account) external;

    function executePromise(uint256 id, address account) external;

    function closePendingPromiseAmount(uint256 id) external;

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

    function accountPromises(address account)
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory debt,
            uint256[] memory receiving,
            uint256[] memory expiry,
            address[] memory tokens
        );
}
