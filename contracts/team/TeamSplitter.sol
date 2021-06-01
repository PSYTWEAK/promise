/* // SPDX-License-Identifier: MIT

pragma solidity ^0.7.1;

import "../interfaces/IERC20.sol";
import "../lib/SafeERC20.sol";

contract PromTeamSplitter {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  uint256[] public pay_table;
  uint8 public constant payee_count = 4;
  uint16 public constant scale = 100;

  constructor () {

    pay_table = [
      pack(address(), 10),  // 10%
      pack(address(), 10),  // 10%
      pack(address(), 10),  // 10%
      pack(address(), 70),  // 70%
    ];

    uint sum;
    uint rate;
    for (uint8 i = 0; i < payee_count - 1; i++) {
      (, rate) = unpack(pay_table[i]);
      sum += rate;
    }

    require(payee_count == pay_table.length, "bad pay table length");
    require(sum < scale, "bad pay table");
  }

  // Allows rotating keys in event of wallet compromise or migration
  // Does not help in the case of lost keys or forgotten password
  function update_address(uint8 index, address new_address) public {
    require(new_address != address(0), "0 addr");
    require(index < payee_count, "bad index");

    address addr;
    uint16 rate;

    (addr, rate) = unpack(pay_table[index]);

    require(msg.sender == addr, "E403");

    pay_table[index] = pack(new_address, rate);
  }

  function dispatch(address tokenAddr) public {
    uint256 bal = IERC20(tokenAddr).balanceOf(address(this));
    require(bal > 0, "no bal");
    uint256 rem = bal;

    address addr;
    uint16 rate;

    for (uint8 i = 0; i < payee_count - 1; i++) {
      (addr, rate) = unpack(pay_table[i]);
      // if bal (wei) < scale/rate user receives 0
      uint256 amt = bal.mul(rate) / scale;
      rem -= amt;
      IERC20(tokenAddr).safeTransfer(addr, amt);
    }

    (addr, rate) = unpack(pay_table[payee_count - 1]);
    IERC20(tokenAddr).safeTransfer(addr, rem);
  }

  function pack(address addr, uint16 rate) public pure returns (uint256) {
    return uint256(addr) | uint256(rate) << 160;
  }

  function unpack(uint256 value) public pure returns (address, uint16) {
    return (address(value), uint16(value >> 160));
  }
} */