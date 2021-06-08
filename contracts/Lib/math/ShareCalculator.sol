// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.8.0;

library ShareCalculator {
    uint224 constant Q112 = 2**112;

    function divMul(
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

    function decode(uint224 x) public pure returns (uint256 z) {
        z = (x >> 112);
    }
}
