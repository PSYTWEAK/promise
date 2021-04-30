pragma solidity >=0.4.21 <0.7.0;

import {IERC20} from "./interfaces/IERC20.sol";

contract Helper {

    address public immutable prom;

    constructor( address _prom) public {
        prom = _prom;
    }
    function getAssetData(address asset, address account) public view returns (string memory, string memory, uint, uint, uint) {
        IERC20 token = IERC20(asset);
        return (token.name(),token.symbol(), token.decimals(), token.allowance(account, address(prom)), token.balanceOf(account));
    }
}