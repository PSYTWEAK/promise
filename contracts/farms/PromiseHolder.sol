// SPDX-License-Identifier: MIT

pragma solidity >=0.4.21 <0.8.0;

import {IERC20} from "../interfaces/IERC20.sol";
import {Ownable} from "../lib/Ownable.sol";
import {IPromiseCore} from "../interfaces/IPromiseCore.sol";

contract PromiseHolder is Ownable {
    address public promiseCore;

    constructor(address _promiseCore, address promiseChef) public Ownable(promiseChef) {
        promiseCore = _promiseCore;
    }

    function approvePromiseChef(address token) external {
        IERC20(token).approve(owner(), 2**256 - 1);
    }

    function closePendingPromiseAmount(uint256 id) external onlyOwner {
        IPromiseCore(promiseCore).closePendingPromiseAmount(id);
    }
}
