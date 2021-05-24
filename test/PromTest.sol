// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "../contracts/p/interfaces/IPromiseCore.sol";
import "./IERC20.sol";

contract PromTest {
    address public token1;
    address public token2;
    address public promiseCore;

    function setTokens(address t1, address t2) public {
        token1 = t1;
        token2 = t2;
    }

    function setPromiseCore(address p) public {
        promiseCore = p;
    }

    function createPromise() public {
        uint256 balance = IERC20(token1).balanceOf(address(this));
        uint112 amount = 1000;
        approve();
        IPromiseCore(promiseCore).createPromise(
            address(this),
            token1,
            amount,
            token2,
            amount,
            block.timestamp + 11 minutes
        );
    }

    function joinPromise(uint256 id, uint112 amount) public {
        IPromiseCore(promiseCore).joinPromise(id, address(this), amount);
    }

    function closePending(uint256 id) public {
        IPromiseCore(promiseCore).closePendingPromiseAmount(id);
    }

    function approve() public {
        IERC20(token1).approve(promiseCore, 2**256 - 1);
        IERC20(token2).approve(promiseCore, 2**256 - 1);
    }

    function getListId(address account) public view returns (bytes32 z) {
        z = sha256(abi.encodePacked(account));
    }
}
