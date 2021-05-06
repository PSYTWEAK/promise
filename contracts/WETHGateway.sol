pragma solidity >=0.4.21 <0.7.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IPromController} from "./interfaces/IPromController.sol";
import {SafeMath} from "./Lib/SafeMath.sol";

contract WETHGateway {
    address public immutable WETH;
    address public immutable prom;

    constructor(address _WETH, address _prom) public {
        WETH = _WETH;
        prom = _prom;
    }

    function approveProm() external {
        IWETH(WETH).approve(address(prom), 2**256 - 1);
    }

    function createPromiseWithETH(
        address account,
        uint256 amountB,
        address assetB,
        uint256 time
    ) external payable {
        IWETH(WETH).deposit{value: msg.value}();
        IPromController(prom).createPromise(account, msg.value.mul(2), WETH, amountB, assetB, time);
    }

    function joinPromiseWithETH(uint256 id, address account) external payable {
        IWETH(WETH).deposit{value: msg.value}();
        IPromController(prom).joinPromise(id, account);
    }

    function payPromiseWithETH(uint256 id, address account) external payable {
        IWETH(WETH).deposit{value: msg.value}();
        IPromController(prom).payPromise(id, account);
    }
}
