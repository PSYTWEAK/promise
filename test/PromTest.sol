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
    uint112 amount = 1000;
    address joiner = address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    address joiner2 = address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);

    function setTokens(address t1, address t2) public {
        token1 = t1;
        token2 = t2;
    }

    function setPromiseCore(address p) public {
        promiseCore = p;
    }

    function testEverything() public {
        createPromise();
        joinerJoinAllPromises();
        payAllPromisesForCreatoreNJoiner();
        executeAllPromisesForCreatorNJoiner();
    }

    function TestCreateJoinPay() public {
        createPromise();
        joinerJoinAllPromises();
        payAllPromisesForCreatoreNJoiner();
    }

    function TestExecute() public {
        executeAllPromisesForCreatorNJoiner();
    }

    function joinerJoinAllPromises() public {
        uint256[] memory id;
        (id, , , ) = IPromiseCore(promiseCore).joinablePromises(token1, token2);
        for (uint256 i = 0; i < id.length; i++) {
            joinPromise(id[i], joiner);
            joinPromise(id[i], joiner2);
        }
    }

    function executeAllPromisesForCreatorNJoiner() public {
        uint256[] memory id;
        uint256[] memory receiving;

        (id, , receiving, , ) = IPromiseCore(promiseCore).accountPromises(address(this));
        for (uint256 i = 0; i < id.length; i++) {
            uint256 balanceBefore = checkBalance(token2);
            _executePromise(id[i], address(this));
            _executePromise(id[i], joiner);
            _executePromise(id[i], joiner2);
            uint256 balanceAfter = checkBalance(token2);
            require(
                balanceBefore - balanceAfter == receiving[i] - ((receiving[i] * 2) / 100),
                "balance after execute is incorrect"
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

    function createPromise() public {
        uint256 balanceBefore = IERC20(token1).balanceOf(address(this));
        approve();
        uint112 randomAmount = uint112(randomNumber());
        IPromiseCore(promiseCore).createPromise(
            address(this),
            token1,
            randomAmount,
            token2,
            uint112(randomNumber()),
            block.timestamp + 40 seconds
        );
        uint256 balanceAfter = IERC20(token1).balanceOf(address(this));
        require(balanceBefore - balanceAfter == randomAmount / 2, "wrong amount taken");
    }

    function joinPromise(uint256 id, address account) public {
        IPromiseCore(promiseCore).joinPromise(id, account, amount / 2);
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

    function checkBalance(address token) public view returns (uint256 z) {
        z = IERC20(token).balanceOf(address(this));
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
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % 1e18;
        nonce++;
        return randomNumber;
    }
}
