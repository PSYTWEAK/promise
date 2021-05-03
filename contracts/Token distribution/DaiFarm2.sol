// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {UQ112x112} from "./Lib/UQ112x112.sol";

import "openzeppelin-solidity-2.3.0/contracts/math/Math.sol";
import "openzeppelin-solidity-2.3.0/contracts/math/SafeMath.sol";
import "openzeppelin-solidity-2.3.0/contracts/token/ERC20/ERC20Detailed.sol";
import "openzeppelin-solidity-2.3.0/contracts/token/ERC20/SafeERC20.sol";
import "openzeppelin-solidity-2.3.0/contracts/utils/ReentrancyGuard.sol";

// Inheritance
import "./interfaces/IStakingRewards.sol";
import "./RewardsDistributionRecipient.sol";
import "./Pausable.sol";

contract DaiFarm {

    PromiseOptions[3] public promiseOptions;
    address public PromiseToken;
    address public WETH;
    address public DAI;

    struct PromiseOptions {
        uint ratio;
        uint time;
    }

    struct PromData {
        /** ---------------------
         a is the creator
         b is the joiner
         time is the minimum date it can be executed
        --------------------- **/
        address addrA;
        uint256 amountA;
        address assetA;
        uint256 owedA;
        address addrB;
        uint256 amountB;
        address assetB;
        uint256 owedB;
        uint256 time;
        bool executed;
    }

    constructor(address weth, address dai, uint[] ratio, uint[] time) public {
        WETH = weth;
        DAI = dai;
        for (uint i; i < 2; i++) {
            promiseOptions[i].ratio = _ratios[i];
            promiseOptions[i].times = _times[i];
        }

    }

    function createPromise(uint _amount, uint optionIndex) external nonReentrant  {
        require(amount > 0, "Cannot stake 0");
        uint amount = ((_amount * 1 ether) * promiseOptions[optionIndex].ratio) / 1 ether;
        token.transferFrom(msg.sender, address(this));
        IPromController(prom).createPromise(msg.sender, amount, DAI, amount, WETH, promiseOptions[optionIndex].time);
        emit Staked(msg.sender, amount);
    }

    function claimRewards(uint id) external nonReentrant  { 
        PromData memory promData = promises[id];
        require(promData.addrB != address(0x0));
        require(promData.addrA == msg.sender);
        uint lengthOfTime = block.timestamp - promData.time;
        uint balance = PromiseToken.balanceOf(address(this));
        


    }

    function updateOptions(uint[] ratio, uint[] time) external onlyOwner {
        require(ratio.length == 3 && time.length == 3);
        for (uint i; i < 2; i++) {
            promiseOptions[i].ratio = _ratios[i];
            promiseOptions[i].times = _times[i];
        }
    }



}