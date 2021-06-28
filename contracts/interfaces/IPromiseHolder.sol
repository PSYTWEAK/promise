// SPDX-License-Identifier: MIT

pragma solidity >=0.4.21 <0.8.0;

interface IPromiseHolder {
    function approvePromiseChef(address token) external;

    function closePendingPromiseAmount(uint256 id) external;
}
