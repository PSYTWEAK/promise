pragma solidity >=0.4.21 <0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";

contract Helper {
    address public immutable prom;

    constructor(address _prom) public {
        prom = _prom;
    }

    function getAssetData(address asset, address account)
        public
        view
        returns (
            string memory,
            string memory,
            uint256,
            uint256,
            uint256
        )
    {
        IERC20 token = IERC20(asset);
        return (token.name(), token.symbol(), token.decimals(), token.allowance(account, address(prom)), token.balanceOf(account));
    }
}
