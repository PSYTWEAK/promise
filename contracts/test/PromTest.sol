// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import {IPromiseCore} from "../interfaces/IPromiseCore.sol";
import {IPromiseFinder} from "../interfaces/IPromiseFinder.sol";
import {IERC20} from "../interfaces/IERC20.sol";

contract PromTest {
    uint112 nonce;
    address public token1;
    address public token2;
    IPromiseCore public promiseCore;
    IPromiseFinder public promiseFinder;
    address alice = address(0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC);
    address bob = address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
    uint256 currentId;
    uint256 currentExpiry;
    uint112 currentCreatorAmount;
    uint112 currentJoinerAmount;
    uint256[] promiseIds;
    uint256 creatorOutstandingDebt;

    event debtOwed(uint256 outstandingDebt, uint256 projectedOutstandingDebt);
    event paid(uint256 shouldPaidThis, uint256 wasPaidThis);
    event leftOver(uint256 creatorTokenAmount, uint256 joinerTokenAmount);
    event joinedWith(uint256 amountToJoin, uint256 amountJoinedWith);

    constructor(
        IPromiseCore _promiseCore,
        IPromiseFinder _promiseFinder,
        address _t1,
        address _t2
    ) {
        promiseCore = _promiseCore;
        promiseFinder = _promiseFinder;
        token1 = _t1;
        token2 = _t2;
    }

    /* creating a promise with contract as creator
       joining promise with alice doing all of the joiner amount
       paying promise for creator & alice */
    function scenario1() public {
        approve();
        createPromise();
        uint256 joinerAmount;
        (, joinerAmount) = getJoinablePromisesAmounts(currentId, token1, token2);
        joinPromise(currentId, alice, uint112(joinerAmount));
        payPromise(currentId, address(this));
        payPromise(currentId, alice);
    }

    // executes promises for creator & alice
    function scenario1Execution() public {
        executePromise(currentId, address(this));
        executePromise(currentId, alice);
    }

    /* creating a promise with contract as creator
    joining promise with alice and bob fragmented amounts each leaving an active amount left
    paying promise for creator, alice and bob */
    function scenario2() public {
        approve();
        createPromise();
        uint256 joinerAmount;
        (, joinerAmount) = getJoinablePromisesAmounts(currentId, token1, token2);
        joinPromise(currentId, alice, uint112(joinerAmount) / 3);
        joinPromise(currentId, bob, uint112(joinerAmount) / 5);
        payPromise(currentId, address(this));
        payPromise(currentId, alice);
        payPromise(currentId, bob);
    }

    // executes promises for creatore, alice, bob
    function scenario2Execution() public {
        executePromise(currentId, address(this));
        executePromise(currentId, alice);
        executePromise(currentId, bob);
    }

    /* creating a promise with contract as creator
    joining promise with alice and bob fragmented amounts each leaving an active amount left
    paying promise for creator and bob */
    function scenario3() public {
        approve();
        createPromise();
        uint256 joinerAmount;
        (, joinerAmount) = getJoinablePromisesAmounts(currentId, token1, token2);
        joinPromise(currentId, alice, uint112(joinerAmount) / 10);
        joinPromise(currentId, bob, uint112(joinerAmount) / 7);
        payPromise(currentId, address(this));
        payPromise(currentId, bob);
    }

    // executes promises for creatore, alice, bob
    function scenario3Execution() public {
        executePromise(currentId, address(this));
        executePromise(currentId, bob);
    }

    /* creating a promise with contract as creator
    joining promise with alice and bob fragmented amounts but bob joins twice
    each leaving an active amount left
    paying promise for alice and bob */
    function scenario4() public {
        approve();
        createPromise();
        uint256 joinerAmount;
        (, joinerAmount) = getJoinablePromisesAmounts(currentId, token1, token2);
        joinPromise(currentId, alice, uint112(joinerAmount) / 10);
        joinPromise(currentId, bob, uint112(joinerAmount) / 10);
        payPromise(currentId, alice);
        payPromise(currentId, bob);
    }

    // executes promises for alice and bob
    function scenario4Execution() public {
        executePromise(currentId, alice);
        executePromise(currentId, bob);
        executePromise(currentId, address(this));
    }

    function scenario5() public {
        createPromise();
    }

    function scenario5JoiningAndPaying(address account) public {
        uint256 joinerAmount;
        (, joinerAmount) = getJoinablePromisesAmounts(currentId, token1, token2);
        joinPromise(currentId, account, uint112(joinerAmount) / 100);
        emit joinedWith(joinerAmount, uint112(joinerAmount) / 100);

        payPromise(currentId, account);
    }

    // creator closes pending amount
    function scenario5ClosePendingAmount() public {
        promiseCore.closePendingPromiseAmount(currentId);
    }

    // executes promises for alice and bob
    function scenario5Execution(address account) public {
        executePromise(currentId, account);
    }

    // executes promises for alice and bob
    function scenario5ForCreator() public {
        executePromise(currentId, address(this));
    }

    function createPromise() public {
        approve();
        uint112 amountIn = getRandomNumber();
        uint112 amountOut = getRandomNumber();
        uint256 balanceBefore = IERC20(token1).balanceOf(address(this));
        promiseCore.createPromise(address(this), token1, amountIn, token2, amountOut, block.timestamp + 5 days);
        uint256 balanceAfter = IERC20(token1).balanceOf(address(this));
        require(balanceBefore - balanceAfter == amountIn / 2, "wrong amount taken during creation");
        currentId++;
        currentExpiry = block.timestamp + 5 days;
        currentCreatorAmount = amountIn;
        currentJoinerAmount = amountOut;
        promiseIds.push(currentId);
        checkAccountPromisesIsCorrect(currentId, address(this), amountIn / 2);
        creatorOutstandingDebt = amountIn / 2;
        checkJoinablePromisesIsCorrect(currentId, token1, token2, amountIn, amountOut);
    }

    function createPromise_2() public {
        approve();
        uint112 amountIn = getRandomNumber();
        uint112 amountOut = getRandomNumber();
        uint256 balanceBefore = IERC20(token1).balanceOf(address(this));
        promiseCore.createPromise(address(this), token1, amountIn, token2, amountOut, block.timestamp + 6 days);
        uint256 balanceAfter = IERC20(token1).balanceOf(address(this));
        require(balanceBefore - balanceAfter == amountIn / 2, "wrong amount taken during creation");
        currentId++;
        currentExpiry = block.timestamp + 6 days;
        currentCreatorAmount = amountIn;
        currentJoinerAmount = amountOut;
        promiseIds.push(currentId);
        checkAccountPromisesIsCorrect(currentId, address(this), amountIn / 2);
        creatorOutstandingDebt = amountIn / 2;
        checkJoinablePromisesIsCorrect(currentId, token1, token2, amountIn, amountOut);
    }

    function joinPromise(
        uint256 id,
        address account,
        uint112 _amount
    ) public {
        uint256 balanceBefore = IERC20(token2).balanceOf(address(this));
        promiseCore.joinPromise(id, account, _amount);
        uint256 balanceAfter = IERC20(token2).balanceOf(address(this));
        require(balanceBefore - balanceAfter == _amount / 2, "wrong amount taken during joining");
        checkAccountPromisesIsCorrect(id, account, _amount / 2);
    }

    function payPromise(uint256 _id, address account) public {
        uint256 balanceBefore;
        uint256 balanceAfter;
        uint256 debt;
        (, debt) = getReceivingAndOutstandingDebt(_id, account);
        if (account == address(this)) {
            balanceBefore = IERC20(token1).balanceOf(address(this));
            promiseCore.payPromise(_id, account);
            balanceAfter = IERC20(token1).balanceOf(address(this));
            require(debt == balanceBefore - balanceAfter, "incorrect amount paid to the promise by creator");
            creatorOutstandingDebt = 0;
        } else {
            balanceBefore = IERC20(token2).balanceOf(address(this));
            promiseCore.payPromise(_id, account);
            balanceAfter = IERC20(token2).balanceOf(address(this));
            require(debt == balanceBefore - balanceAfter, "incorrect amount paid to the promise by joiner");
        }
        checkAccountPromisesIsCorrect(_id, account, 0);
    }

    function executePromise(uint256 _id, address account) public {
        uint256 balanceBefore;
        uint256 balanceAfter;
        uint256 receiving;
        (receiving, ) = getReceivingAndOutstandingDebt(_id, account);
        if (account == address(this)) {
            balanceBefore = IERC20(token2).balanceOf(account);
            promiseCore.executePromise(_id, account);
            balanceAfter = IERC20(token2).balanceOf(account);
            bool greaterThan = (receiving - (((receiving) * 50) / 10000)) > (balanceAfter - balanceBefore);
            bool lessThan = (receiving - (((receiving) * 50) / 10000)) < (balanceAfter - balanceBefore);
            require(!greaterThan, "lower amount paid to the creator at execution");
            require(!lessThan, "higher amount paid to the creator at execution");
        } else {
            balanceBefore = IERC20(token1).balanceOf(account);
            promiseCore.executePromise(_id, account);
            balanceAfter = IERC20(token1).balanceOf(account);
            bool greaterThan = (receiving - (((receiving) * 50) / 10000)) > (balanceAfter - balanceBefore);
            bool lessThan = (receiving - (((receiving) * 50) / 10000)) < (balanceAfter - balanceBefore);
            require(!greaterThan, "lower amount paid to the creator at execution");
            require(!lessThan, "higher amount paid to the creator at execution");
        }

        checkRemovedFromAccountPromises(_id, account);
        checkRemovedFromJoinablePromises(_id);
    }

    function checkAccountPromisesIsCorrect(
        uint256 _id,
        address account,
        uint256 _outstandingDebt
    ) public {
        uint256[] memory id;
        uint256[] memory receiving;
        uint256[] memory outstandingDebt;
        (id, outstandingDebt, receiving, , ) = promiseFinder.accountPromises(account);
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 40, "ID not found in account promises");
        }
        emit debtOwed(outstandingDebt[i], _outstandingDebt);
        require(outstandingDebt[i] == _outstandingDebt, "outstanding debt on account promises is incorrect");
    }

    function checkRemovedFromAccountPromises(uint256 _id, address account) public view {
        uint256[] memory id;
        uint256[] memory receiving;
        uint256[] memory outstandingDebt;
        (id, outstandingDebt, receiving, , ) = promiseFinder.accountPromises(account);
        uint256 i;
        while (i < id.length) {
            require(_id != id[i], "Promise wasn't removed from account promises");
            i++;
        }
    }

    function checkRemovedFromJoinablePromises(uint256 _id) public view {
        uint256[] memory id;
        (id, , , ) = promiseFinder.joinablePromises(
            token1,
            token2,
            currentExpiry,
            currentCreatorAmount,
            currentJoinerAmount
        );
        uint256 i;
        while (i < id.length) {
            require(_id != id[i], "Promise wasn't removed from joinable promises");
            i++;
        }
    }

    function getReceivingAndOutstandingDebt(uint256 _id, address account) public view returns (uint256 a, uint256 b) {
        uint256[] memory id;
        uint256[] memory receiving;
        uint256[] memory outstandingDebt;
        (id, outstandingDebt, receiving, , ) = promiseFinder.accountPromises(account);
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 40, "Promise not in account promises");
        }
        a = receiving[i];
        b = outstandingDebt[i];
    }

    function checkJoinablePromisesIsCorrect(
        uint256 _id,
        address _token1,
        address _token2,
        uint112 _creatorAmount,
        uint112 _joinerAmount
    ) public {
        uint256[] memory id;
        uint256[] memory creatorAmount;
        uint256[] memory joinerAmount;
        (id, , , ) = promiseFinder.joinablePromises(
            _token1,
            _token2,
            currentExpiry,
            currentCreatorAmount,
            currentJoinerAmount
        );
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 40, "ID not found in account promises");
        }
    }

    function getJoinablePromisesAmounts(
        uint256 _id,
        address _token1,
        address _token2
    ) public view returns (uint256 a, uint256 b) {
        uint256[] memory id;
        uint256[] memory creatorAmount;
        uint256[] memory joinerAmount;
        (id, creatorAmount, joinerAmount, ) = promiseFinder.joinablePromises(
            _token1,
            _token2,
            currentExpiry,
            currentCreatorAmount,
            currentJoinerAmount
        );
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 40, "ID not found in account promises");
        }
        a = creatorAmount[i];
        b = joinerAmount[i];
    }

    function getRandomNumber() public returns (uint112) {
        nonce++;
        uint112 ranNum = randomNumber();
        return ranNum;
    }

    function randomNumber() public view returns (uint112) {
        uint256 a = (uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % 33);
        uint256 b = (uint256(keccak256(abi.encodePacked(block.timestamp * 2, nonce))) % 60);
        uint112 c = uint112(uint256(a << b));
        if (c < 100) {
            c = 10**18;
        }
        return c;
    }

    function approve() public {
        IERC20(token1).approve(address(promiseCore), 2**256 - 1);
        IERC20(token2).approve(address(promiseCore), 2**256 - 1);
    }

    function checkBalance(address token, address account) public view returns (uint256 z) {
        z = IERC20(token).balanceOf(account);
    }

    function hasLeftOver() public {
        uint256 bal = checkBalance(token1, address(promiseCore)) + checkBalance(token2, address(promiseCore));
        emit leftOver(checkBalance(token1, address(promiseCore)), checkBalance(token2, address(promiseCore)));
        //require(bal == 0, "Promise contract was left with some tokens");
    }
}
