// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.8.0;

interface IOwnershipTransferrable {
    function transferOwnership(address owner) external;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}

pragma solidity >=0.4.21 <0.8.0;

contract Ownable is IOwnershipTransferrable {
    address private _owner;

    constructor(address owner) public {
        _owner = owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external override onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
