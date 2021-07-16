// SPDX-License-Identifier: MIT

pragma solidity >=0.4.21 <0.8.0;

import {SafeMath} from "../lib/math/SafeMath.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "../lib/SafeERC20.sol";
import {Ownable} from "../lib/Ownable.sol";

import {PromiseToken} from "../token/PromiseToken.sol";
import {PromiseCore} from "../PromiseCore.sol";
import {PromiseList} from "../PromiseList.sol";
import {IPromiseHolder} from "../interfaces/IPromiseHolder.sol";

interface IPromiseChef {
    function poolLength() external view returns (uint256);

    function add(
        uint256 _allocPoint,
        IERC20 _creatorToken,
        address _joinerToken,
        uint256[2] memory _minUncalculatedRatio,
        uint256[2] memory _maxUncalculatedRatio,
        bool _withUpdate,
        uint256 _expirationDate
    ) external;

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) external;

    function getMultiplier(uint256 _from, uint256 _to) external pure returns (uint256);

    function pendingProm(uint256 _pid, address _user) external view returns (uint256);

    function massUpdatePools() external;

    function updatePool(uint256 _pid) external;

    function createPromise(
        uint256 _pid,
        uint256 _creatorAmount,
        uint256 _joinerAmount
    ) external;

    function payPromise(uint256 id) external;

    function executePromise(
        uint256 _pid,
        uint256 promiseId,
        address account
    ) external;

    function closePendingPromiseAmount(uint256 _pid, uint256 promiseId) external;

    function claimReward(uint256 _pid) external;

    function setPromiseHolder(address _promiseHolder) external;

    function updateEmissionRate(uint256 _promPerBlock) external;
}
