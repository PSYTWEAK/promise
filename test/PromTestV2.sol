// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "../contracts/interfaces/IPromiseCore.sol";
import "../contracts/interfaces/IERC20.sol";

contract PromTest {
    uint112 nonce;
    address public token1;
    address public token2;
    address public promiseCore;
    address alice = address(0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC);
    address bob = address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
    uint256 currentId;
    uint256[] promiseIds;

    constructor(
        address _promiseCore,
        address _t1,
        address _t2
    ) {
        promiseCore = _promiseCore;
        token1 = _t1;
        token2 = _t2;
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
            block.timestamp + 1 minutes
        );
        uint256 balanceAfter = IERC20(token1).balanceOf(address(this));
        require(balanceBefore - balanceAfter == amountIn / 2, "wrong amount taken during creation");
        currentId++;
        promiseIds.push(currentId);
        checkAccountPromisesIsCorrect(currentId, address(this), amountIn / 2);
        checkJoinablePromisesIsCorrect(currentId, token1, token2, amountIn, amountOut);
    }

    function joinPromise(
        uint256 id,
        address account,
        uint112 _amount
    ) public {
        uint256 balanceBefore = IERC20(token2).balanceOf(account);
        IPromiseCore(promiseCore).joinPromise(id, account, _amount);
        uint256 balanceAfter = IERC20(token2).balanceOf(account);
        require(balanceBefore - balanceAfter == _amount / 2, "wrong amount taken during joining");
        uint debt;
        (,debt) = getReceivingAndOutstandingDebt(_id, account);
        require(debt == _amount / 2, "wrong amount of debt")
        checkAccountPromisesIsCorrect(id, account, _amount / 2);
    }

    function payPromise(uint256 _id, address account) public {
        uint256 balanceBefore;
        uint256 balanceAfter;
        uint debt;
        (, debt) = getReceivingAndOutstandingDebt(_id, account);
        if (account == address(this)) {
            balanceBefore = IERC20(token1).balanceOf(account);
            IPromiseCore(promiseCore).payPromise(_id, account);
            balanceAfter = IERC20(token1).balanceOf(account);
        require(debt == balanceBefore - balanceAfter, "incorrect amount paid to the promise by creator")
        } else {
            balanceBefore = IERC20(token2).balanceOf(account);
            IPromiseCore(promiseCore).payPromise(_id, account);
            balanceAfter = IERC20(token2).balanceOf(account);
        require(debt == balanceBefore - balanceAfter, "incorrect amount paid to the promise by joiner")
        }
        checkAccountPromisesIsCorrect(_id, account, (balanceAfter - balanceBefore));
    }

    function executePromise(uint256 _id, address account) public {
        uint256 balanceBefore;
        uint256 balanceAfter;
        uint receiving;
        (receiving, ) = getReceivingAndOutstandingDebt(_id, account);
        if (account == address(this)) {
            balanceBefore = IERC20(token2).balanceOf(account);
            IPromiseCore(promiseCore).executePromise(_id, account);
            balanceAfter = IERC20(token2).balanceOf(account);
        require(receiving == ((balanceAfter - balanceBefore)*2 / 100), "incorrect amount paid to the creator at execution")
        } else {
            balanceBefore = IERC20(token1).balanceOf(account);
            IPromiseCore(promiseCore).executePromise(_id, account);
            balanceAfter = IERC20(token1).balanceOf(account);
        require(receiving == ((balanceAfter - balanceBefore)*2 / 100), "incorrect amount paid to the joiner at execution")
        }
        checkRemovedFromAccountPromises(_id, account);
    }

    function approve() public {
        IERC20(token1).approve(promiseCore, 2**256 - 1);
        IERC20(token2).approve(promiseCore, 2**256 - 1);
    }

    function checkAccountPromisesIsCorrect(
        uint256 _id,
        address account,
        uint256 _outstandingDebt
    ) public view {
        uint256[] memory id;
        uint256[] memory receiving;
        uint256[] memory outstandingDebt;
        (id, , receiving, outstandingDebt, ) = IPromiseCore(promiseCore).accountPromises(account);
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
        (id, , receiving, outstandingDebt, ) = IPromiseCore(promiseCore).accountPromises(account);
        uint256 i;
        while (_id != id[i] || i > 9) {
            i++;
            if (_id == id[i]) {
                require(1 == 0, "Promise wasn't removed from account promises");
            }
        }
    }

    function getReceivingAndOutstandingDebt(uint256 _id, address account) public view returns (uint256, uint256) {
        uint256[] memory id;
        uint256[] memory receiving;
        uint256[] memory outstandingDebt;
        (id, , receiving, outstandingDebt, ) = IPromiseCore(promiseCore).accountPromises(account);
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 10, "Promise not in account promises");
        }
        return (receiving[i], outstandingDebt[i]);
    }

    function checkJoinablePromisesIsCorrect(
        uint256 _id,
        address _token1,
        address _token2,
        uint112 _creatorAmount,
        uint112 _joinerAmount
    ) public view {
        uint256[] memory id;
        uint256[] memory creatorAmount;
        uint256[] memory joinerAmount;
        (id, , , ) = IPromiseCore(promiseCore).joinablePromises(_token1, _token2);
        uint256 i;
        while (_id != id[i]) {
            i++;
            require(i < 10, "ID not found in account promises");
        }
        require(creatorAmount[i] == _creatorAmount, "amount in on joinable promises is incorrect");
        require(joinerAmount[i] == _joinerAmount, "amount out on joinable promises is incorrect");
    }

    function getRandomNumber() public returns (uint112) {
        nonce++;
        uint112 ranNum = randomNumber();
        return ranNum;
    }

    function randomNumber() public view returns (uint112) {
        return uint112(uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % 1e18);
    }
}
