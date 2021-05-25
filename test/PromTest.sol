// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "../contracts/p/interfaces/IPromiseCore.sol";
import "./IERC20.sol";

contract PromTest {
    uint224 constant Q112 = 2**112;
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
        uint256[] memory debt;
        uint256[] memory receiving;
        uint256[] memory expiry;
        address[] memory tokens;
        (id, debt, receiving, expiry, tokens) = IPromiseCore(promiseCore).accountPromises(address(this));
        for (uint256 i = 0; i < id.length; i++) {
            joinPromise(id[i], joiner);
            joinPromise(id[i], joiner2);
        }
    }

    function executeAllPromisesForCreatorNJoiner() public {
        uint256[] memory id;
        uint256[] memory debt;
        uint256[] memory receiving;
        uint256[] memory expiry;
        address[] memory tokens;
        (id, debt, receiving, expiry, tokens) = IPromiseCore(promiseCore).accountPromises(address(this));
        for (uint256 i = 0; i < id.length; i++) {
            _executePromise(id[i], address(this));
            _executePromise(id[i], joiner);
            _executePromise(id[i], joiner2);
        }
    }

    function payAllPromisesForCreatoreNJoiner() public {
        uint256[] memory id;
        uint256[] memory debt;
        uint256[] memory receiving;
        uint256[] memory expiry;
        address[] memory tokens;
        (id, debt, receiving, expiry, tokens) = IPromiseCore(promiseCore).accountPromises(address(this));
        for (uint256 i = 0; i < id.length; i++) {
            _payPromise(id[i], address(this));
            _payPromise(id[i], joiner);
            _payPromise(id[i], joiner2);
        }
    }

    function createPromise() public {
        uint256 balance = IERC20(token1).balanceOf(address(this));
        approve();
        IPromiseCore(promiseCore).createPromise(
            address(this),
            token1,
            amount,
            token2,
            amount,
            block.timestamp + 10 seconds
        );
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

    function getListId(address account) public view returns (bytes32 z) {
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
    function encode(uint112 y) public view returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function div(uint224 x, uint112 y) public view returns (uint224 z) {
        z = x / uint224(y);
    }

    function mul(uint224 x, uint224 y) public view returns (uint224 z) {
        z = x * y;
        if (x == 0) {
            z = 0;
        }
    }

    function decode(uint224 x) public view returns (uint256 z) {
        z = (x >> 112);
    }
}
