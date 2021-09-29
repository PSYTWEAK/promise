// SPDX-License-Identifier: MIT

pragma solidity >=0.4.21 <0.8.4;

interface IPromiseCore {
    event PromiseCreated(
        uint256 id,
        address creator,
        address creatorToken,
        uint256 creatorAmount,
        address joinerToken,
        uint256 joinerAmount,
        uint256 expirationTimestamp
    );

    event PromiseJoined(uint256 id, address joiner, uint256 amount);
    event PromisePendingAmountClosed(uint256 id, address executor, uint256 refund);
    event PromiseExecuted(uint256 id, address account, uint256 creatorTokenAmount, uint256 joinerTokenAmount);
    event PromisePaid(uint256 id, address account, uint256 amount);

    function createPromise(
        address account,
        address creatorToken,
        uint112 creatorAmount,
        address joinerToken,
        uint112 joinerAmount,
        uint256 expirationTimestamp
    ) external;

    function joinPromise(
        uint256 id,
        address account,
        uint112 amount
    ) external;

    function payPromiseAsCreator(uint256 id, address account) external;

    function payPromiseAsJoiner(uint256 id, address account) external;

    function closePendingPromiseAmount(uint256 id) external;

    function executePromiseAsCreator(uint256 id, address account) external;

    function executePromiseAsJoiner(uint256 id, address account) external;

    function getRemainingCreatorAmountAfterClosingPromise(uint256 id) external returns (uint112);

    function getJoinerId(uint256 id, address account) external returns (bytes32);

    function getRemainingAmountAbleToJoinPromise(uint256 id) external returns (uint256);

    function getTotalJoinerFundsInPromise(uint256 id) external returns (uint112);

    function getCreatorRefundAmount(uint256 id) external returns (uint256);

    function getPayoutAmountsForCreator(uint256 id) external returns (uint256, uint256);

    function getPayoutAmountsForJoiner(uint256 id, bytes32 joinerId) external returns (uint256, uint256);
}
