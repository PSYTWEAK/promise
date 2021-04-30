// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;


interface IPromController {

    event PromiseCreated(address addrA, uint256 amountA, address assetA, uint256 amountB, address assetB, uint256 time);
    event PromiseJoined(address addrB, uint256 id);
    event PromiseCanceled(uint256 id);
    event PromiseExecuted(address executor, uint256 id);
    function createPromise(
        address account,
        uint256 amountA,
        address assetA,
        uint256 amountB,
        address assetB,
        uint256 time
    ) external;

    function joinPromise(uint256 id, address account) external; 

    function payPromise(uint256 id, address account) external; 

    function executePromise(uint256 id) external;


}
