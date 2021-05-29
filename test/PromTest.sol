// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "../contracts/p/interfaces/IPromiseCore.sol";
import "./IERC20.sol";

contract PromTest {
    uint224 constant Q112 = 2**112;
    uint112 nonce;
    address public token1;
    address public token2;
    address public promiseCore;
    uint112 amount = 10000;
    address joiner = address(0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC);
    address joiner2 = address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);

    constructor(
        address _promiseCore,
        address _t1,
        address _t2
    ) {
        promiseCore = _promiseCore;
        token1 = _t1;
        token2 = _t2;
    }

    function setTokens(address t1, address t2) public {
        token1 = t1;
        token2 = t2;
    }

    function setPromiseCore(address p) public {
        promiseCore = p;
    }

    // Promise is created, creator joins, joiner and joiner 2 join the promise with half of active amount each
    // everyone pays, everyone executes
    function testEverything1() public {
        createPromise();
        joinersJoinAllPromises(amount / 2, amount / 2);
        payAllPromisesForCreatoreNJoiner();
        executeAllPromises();
    }

    // Promise is created, creator joins, joiner and joiner 2 join the promise with none full amounts
    // everyone pays, everyone executes
    function testEverything2() public {
        createPromise();
        joinersJoinAllPromises(amount / 4, amount / 2);
        payAllPromisesForCreatoreNJoiner();
        executeAllPromises();
    }

    // Promise is created, creator joins, joiner and joiner 2 join the promise with none full amounts
    // everyone pays execpt joiner, everyone executes
    function testEverything3() public {
        createPromise();
        joinersJoinAllPromises(amount / 4, amount / 2);
        paySomePromisesForCreatoreNJoiner();
        executeSomePromises();
    }

    function hasLeftOver() public view returns (bool) {
        uint256 bal = checkBalance(token1, promiseCore) + checkBalance(token2, promiseCore);
        return bal > 0;
    }

    function TestCreateJoinPay() public {
        createPromise();
        joinersJoinAllPromises(amount / 2, amount / 2);
        payAllPromisesForCreatoreNJoiner();
    }

    function TestExecute() public {
        executeAllPromises();
    }

    function joinersJoinAllPromises(uint112 _amount, uint112 _amount2) public {
        uint256[] memory id;
        (id, , , ) = IPromiseCore(promiseCore).joinablePromises(token1, token2);
        for (uint256 i = 0; i < id.length; i++) {
            joinPromise(id[i], joiner, _amount);
            joinPromise(id[i], joiner2, _amount2);
        }
    }

    function executeAllPromises() public {
        uint256[] memory id;
        uint256[] memory receiving;

        (id, , receiving, , ) = IPromiseCore(promiseCore).accountPromises(address(this));
        for (uint256 i = 0; i < id.length; i++) {
            uint256 balanceBeforeCreator = checkBalance(token2, address(this));
            _executePromise(id[i], address(this));
            uint256 balanceAfterCreator = checkBalance(token2, address(this));
            require(
                balanceAfterCreator - balanceBeforeCreator == receiving[i] - ((receiving[i] * 2) / 100),
                "incorrect amount received - creator"
            );
        }
        (id, , receiving, , ) = IPromiseCore(promiseCore).accountPromises(joiner);
        for (uint256 i = 0; i < id.length; i++) {
            uint256 balanceBeforeJoiner = checkBalance(token1, joiner);
            _executePromise(id[i], joiner);
            uint256 balanceAfterJoiner = checkBalance(token1, joiner);
            require(
                balanceAfterJoiner - balanceBeforeJoiner == receiving[i] - ((receiving[i] * 2) / 100),
                "incorrect amount received - joiner"
            );
        }
        (id, , receiving, , ) = IPromiseCore(promiseCore).accountPromises(joiner2);
        for (uint256 i = 0; i < id.length; i++) {
            uint256 balanceBeforeJoiner2 = checkBalance(token1, joiner2);
            _executePromise(id[i], joiner2);
            uint256 balanceAfterJoiner2 = checkBalance(token1, joiner2);
            require(
                balanceAfterJoiner2 - balanceBeforeJoiner2 == receiving[i] - ((receiving[i] * 2) / 100),
                "incorrect amount received - joiner2"
            );
        }
    }

    function executeSomePromises() public {
        uint256[] memory id;
        uint256[] memory receiving;

        (id, , receiving, , ) = IPromiseCore(promiseCore).accountPromises(address(this));
        for (uint256 i = 0; i < id.length; i++) {
            uint256 balanceBeforeCreator = checkBalance(token2, address(this));
            _executePromise(id[i], address(this));
            uint256 balanceAfterCreator = checkBalance(token2, address(this));
            require(
                balanceAfterCreator - balanceBeforeCreator == receiving[i] - ((receiving[i] * 2) / 100),
                "incorrect amount received - creator"
            );
        }
        (id, , receiving, , ) = IPromiseCore(promiseCore).accountPromises(joiner2);
        for (uint256 i = 0; i < id.length; i++) {
            uint256 balanceBeforeJoiner2 = checkBalance(token1, joiner2);
            _executePromise(id[i], joiner2);
            uint256 balanceAfterJoiner2 = checkBalance(token1, joiner2);
            require(
                balanceAfterJoiner2 - balanceBeforeJoiner2 == receiving[i] - ((receiving[i] * 2) / 100),
                "incorrect amount received - joiner2"
            );
        }
    }

    function payAllPromisesForCreatoreNJoiner() public {
        uint256[] memory id;
        (id, , , , ) = IPromiseCore(promiseCore).accountPromises(address(this));
        for (uint256 i = 0; i < id.length; i++) {
            _payPromise(id[i], address(this));
            _payPromise(id[i], joiner);
            _payPromise(id[i], joiner2);
        }
    }

    function paySomePromisesForCreatoreNJoiner() public {
        uint256[] memory id;
        (id, , , , ) = IPromiseCore(promiseCore).accountPromises(address(this));
        for (uint256 i = 0; i < id.length; i++) {
            _payPromise(id[i], address(this));
            _payPromise(id[i], joiner2);
        }
    }

    function createPromise() public {
        uint256 balanceBefore = IERC20(token1).balanceOf(address(this));
        approve();
        IPromiseCore(promiseCore).createPromise(
            address(this),
            token1,
            amount,
            token2,
            amount,
            block.timestamp + 40 seconds
        );
        uint256 balanceAfter = IERC20(token1).balanceOf(address(this));
        require(balanceBefore - balanceAfter == amount / 2, "wrong amount taken");
    }

    function joinPromise(
        uint256 id,
        address account,
        uint112 _amount
    ) public {
        IPromiseCore(promiseCore).joinPromise(id, account, _amount);
    }

    function closePending(uint256 id) public {
        IPromiseCore(promiseCore).closePendingPromiseAmount(id);
    }

    function _executePromise(uint256 id, address account) public {
        IPromiseCore(promiseCore).executePromise(id, account);
    }

    function _payPromise(uint256 id, address account) public {
        IPromiseCore(promiseCore).payPromise(id, account);
    }

    function approve() public {
        IERC20(token1).approve(promiseCore, 2**256 - 1);
        IERC20(token2).approve(promiseCore, 2**256 - 1);
    }

    function checkBalance(address token, address account) public view returns (uint256 z) {
        z = IERC20(token).balanceOf(account);
    }

    function getListId(address account) public pure returns (bytes32 z) {
        z = sha256(abi.encodePacked(account));
    }

    function doMath(
        uint112 x,
        uint112 y,
        uint224 z
    ) public view returns (uint256 d) {
        uint224 a = encode(x);
        uint224 b = div(a, y);
        uint224 c = mul(z, b);
        d = decode(c);
    }

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) public pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function div(uint224 x, uint112 y) public pure returns (uint224 z) {
        z = x / uint224(y);
    }

    function mul(uint224 x, uint224 y) public pure returns (uint224 z) {
        z = x * y;
        if (x == 0) {
            z = 0;
        }
    }

    function decode(uint224 x) public view returns (uint256 z) {
        z = (x >> 112);
    }

    function randomNumber() public returns (uint256) {
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % 7437589437;
        nonce++;
        return 10000;
    }
}
