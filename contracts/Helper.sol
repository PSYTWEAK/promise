pragma solidity >=0.4.21 <0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {PromiseChef} from "./farms/PromiseChef.sol";

contract Helper {
    function getAssetData(
        address asset,
        address account,
        address spender
    )
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
        return (
            token.name(),
            token.symbol(),
            token.decimals(),
            token.allowance(account, spender),
            token.balanceOf(account)
        );
    }

    function getPromiseChefPools(address promiseChef)
        public
        view
        returns (address[] memory creatorTokens, address[] memory joinerTokens)
    {
        uint256 poolLength = PromiseChef(promiseChef).poolLength();
        creatorTokens = new address[](poolLength);
        joinerTokens = new address[](poolLength);
        uint256 i;
        IERC20 _creatorToken;
        while (i < poolLength) {
            (_creatorToken, joinerTokens[i], , , , , , , ) = PromiseChef(promiseChef).poolInfo(i);
            creatorTokens[i] = address(_creatorToken);
            i++;
        }
    }
}
