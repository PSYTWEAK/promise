// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "../interfaces/IPromiseCore.sol";
import "../interfaces/IERC20.sol";

contract PromTest {
    uint112 nonce;
    address public token1;
    address public token2;
    address public promiseCore;
    address alice = address(0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC);
    address bob = address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
    uint256 currentId;
    uint256[] promiseIds;
    uint256 creatorOutstandingDebt;

    constructor(
        address _promiseCore,
        address _t1,
        address _t2
    ) {
        promiseCore = _promiseCore;
        token1 = _t1;
        token2 = _t2;
    }

    /* creating a promise with contract as creator
       joining promise with alice and bob 50% each
       paying promise for creator, alice and bob */
    function scenario1() public {
        approve();
        createPromise();
        uint256 joinerAmount;
        (, joinerAmount) = getJoinablePromisesIsCorrect(currentId, token1, token2);
        joinPromise(currentId, alice, uint112(joinerAmount) / 2);
        joinPromise(currentId, bob, uint112(joinerAmount) / 2);
        payPromise(currentId, address(this));
        payPromise(currentId, alice);
        payPromise(currentId, bob);
    }

    // executes promises for creator, alice, bob
    function scenario1Execution() public {
        executePromise(currentId, address(this));
        executePromise(currentId, alice);
        executePromise(currentId, bob);
    }

    /* creating a promise with contract as creator
    joining promise with alice and bob fragmented amounts each leaving an active amount left
    paying promise for creator, alice and bob */
    function scenario2() public {
        approve();
        createPromise();
        uint256 joinerAmount;
        (, joinerAmount) = getJoinablePromisesIsCorrect(currentId, token1, token2);
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
        (, joinerAmount) = getJoinablePromisesIsCorrect(currentId, token1, token2);
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
        (, joinerAmount) = getJoinablePromisesIsCorrect(currentId, token1, token2);
        joinPromise(currentId, alice, uint112(joinerAmount) / 10);
        joinPromise(currentId, bob, uint112(joinerAmount) / 7);
        payPromise(currentId, alice);
        payPromise(currentId, bob);
    }

    // executes promises for alice and bob
    function scenario4Execution() public {
        executePromise(currentId, alice);
        executePromise(currentId, bob);
    }

    function scenario5() public {
        createPromise();
    }

    function scenario5JoiningAndPaying(address account) public {
        uint256 joinerAmount;
        (, joinerAmount) = getJoinablePromisesIsCorrect(currentId, token1, token2);
        joinPromise(currentId, account, uint112(joinerAmount) / 100);
        payPromise(currentId, account);
    }

    function scenario5JoiningAndNotPaying(address account) public {
        uint256 joinerAmount;
        (, joinerAmount) = getJoinablePromisesIsCorrect(currentId, token1, token2);
        joinPromise(currentId, account, uint112(joinerAmount) / 100);
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
        uint112 amountIn = randomNumber();
        uint112 amountOut = randomNumber();
        uint256 balanceBefore = IERC20(token1).balanceOf(address(this));
        IPromiseCore(promiseCore).createPromise(
            address(this),
            token1,
            amountIn,
            token2,
            amountOut,
            block.timestamp + 11 minutes
        );
        uint256 balanceAfter = IERC20(token1).balanceOf(address(this));
        require(balanceBefore - balanceAfter == amountIn / 2, "wrong amount taken during creation");
        currentId++;
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
        IPromiseCore(promiseCore).joinPromise(id, account, _amount);
        uint256 balanceAfter = IERC20(token2).balanceOf(address(this));
        require(balanceBefore - balanceAfter == _amount / 2, "wrong amount taken during joining");
        uint256 debtAfter;
        (, debtAfter) = getReceivingAndOutstandingDebt(id, account);
        require(debtAfter == _amount / 2, "wrong amount of debt");
        checkAccountPromisesIsCorrect(id, account, _amount / 2);
    }

    function payPromise(uint256 _id, address account) public {
        uint256 balanceBefore;
        uint256 balanceAfter;
        uint256 debt;
        (, debt) = getReceivingAndOutstandingDebt(_id, account);
        if (account == address(this)) {
            balanceBefore = IERC20(token1).balanceOf(address(this));
            IPromiseCore(promiseCore).payPromise(_id, account);
            balanceAfter = IERC20(token1).balanceOf(address(this));
            require(debt == balanceBefore - balanceAfter, "incorrect amount paid to the promise by creator");
            creatorOutstandingDebt = 0;
        } else {
            balanceBefore = IERC20(token2).balanceOf(address(this));
            IPromiseCore(promiseCore).payPromise(_id, account);
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
        if (creatorOutstandingDebt > 0) {
            balanceBefore = IERC20(token1).balanceOf(account);
            IPromiseCore(promiseCore).executePromise(_id, account);
            balanceAfter = IERC20(token1).balanceOf(account);
            require(
                ((receiving / 2) - (((receiving / 2) * 3) / 1000)) == (balanceAfter - balanceBefore),
                "incorrect amount paid to the joiner at execution"
            );
        } else {
            if (account == address(this)) {
                balanceBefore = IERC20(token2).balanceOf(account);
                IPromiseCore(promiseCore).executePromise(_id, account);
                balanceAfter = IERC20(token2).balanceOf(account);
                require(
                    (receiving - (((receiving) * 3) / 1000)) == (balanceAfter - balanceBefore),
                    "incorrect amount paid to the creator at execution"
                );
            } else {
                balanceBefore = IERC20(token1).balanceOf(account);
                IPromiseCore(promiseCore).executePromise(_id, account);
                balanceAfter = IERC20(token1).balanceOf(account);
                require(
                    (receiving - (((receiving) * 3) / 1000)) == (balanceAfter - balanceBefore),
                    "incorrect amount paid to the joiner at execution"
                );
            }
        }
        checkRemovedFromAccountPromises(_id, account);
    }

    function checkAccountPromisesIsCorrect(
        uint256 _id,
        address account,
        uint256 _outstandingDebt
    ) public view {
        uint256[] memory id;
        uint256[] memory receiving;
        uint256[] memory outstandingDebt;
        (id, outstandingDebt, receiving, , ) = IPromiseCore(promiseCore).accountPromises(account);
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 10, "ID not found in account promises");
        }
        require(outstandingDebt[i] == _outstandingDebt, "outstanding debt on account promises is incorrect");
    }

    function checkRemovedFromAccountPromises(uint256 _id, address account) public view {
        uint256[] memory id;
        uint256[] memory receiving;
        uint256[] memory outstandingDebt;
        (id, outstandingDebt, receiving, , ) = IPromiseCore(promiseCore).accountPromises(account);
        uint256 i;
        while (i < id.length) {
            require(_id != id[i], "Promise wasn't removed from account promises");
            i++;
        }
    }

    function getReceivingAndOutstandingDebt(uint256 _id, address account) public view returns (uint256 a, uint256 b) {
        uint256[] memory id;
        uint256[] memory receiving;
        uint256[] memory outstandingDebt;
        (id, outstandingDebt, receiving, , ) = IPromiseCore(promiseCore).accountPromises(account);
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 10, "Promise not in account promises");
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
        (id, , , ) = IPromiseCore(promiseCore).joinablePromises(_token1, _token2);
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 10, "ID not found in account promises");
        }
        // assert.equal(creatorAmount[i], _creatorAmount, "amount in on joinable promises is incorrect");
        // assert.equal(joinerAmount[i] , _joinerAmount, "amount out on joinable promises is incorrect");
    }

    function getJoinablePromisesIsCorrect(
        uint256 _id,
        address _token1,
        address _token2
    ) public view returns (uint256 a, uint256 b) {
        uint256[] memory id;
        uint256[] memory creatorAmount;
        uint256[] memory joinerAmount;
        (id, creatorAmount, joinerAmount, ) = IPromiseCore(promiseCore).joinablePromises(_token1, _token2);
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 10, "ID not found in account promises");
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
        return uint112(uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % 1e18);
    }

    function approve() public {
        IERC20(token1).approve(promiseCore, 2**256 - 1);
        IERC20(token2).approve(promiseCore, 2**256 - 1);
    }
}
