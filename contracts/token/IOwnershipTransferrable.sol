// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

interface IOwnershipTransferrable {
    function transferOwnership(address owner) external;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}
