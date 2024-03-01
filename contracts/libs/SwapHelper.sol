// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
pragma abicoder v2;

import "./TransferHelper.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/ISwapRouter02.sol";

library SwapHelper {

    function swapInputETHForToken(address tokenOut, uint24 fee, uint256 amountIn, uint256 amountOutMin, ISwapRouter02 swapRouter, address WETH) internal returns (uint256 amountOut) {
        require(amountIn <= address(this).balance, "Not enough balance");
        IV3SwapRouter.ExactInputSingleParams memory params =
                            IV3SwapRouter.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });
        return swapRouter.exactInputSingle{value: amountIn}(params);
    }

    function swapInputForErc20Token(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint256 amountOutMin, ISwapRouter02 swapRouter, mapping(address => bool) storage approveMap) internal returns (uint256) {
        if(!approveMap[tokenIn]) {
            TransferHelper.safeApprove(tokenIn, address(swapRouter), type(uint256).max);
            approveMap[tokenIn] = true;
        }
        IV3SwapRouter.ExactInputSingleParams memory params =
                            IV3SwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });
        return swapRouter.exactInputSingle(params);
    }

    function swapInputTokenToETH(address tokenIn, uint24 fee, uint256 amountIn, uint256 amountOutMin, ISwapRouter02 swapRouter, address WETH, mapping(address => bool) storage approveMap) internal returns (uint256 amountOut) {
        if(!approveMap[tokenIn]) {
            TransferHelper.safeApprove(tokenIn, address(swapRouter), type(uint256).max);
            approveMap[tokenIn] = true;
        }
        IV3SwapRouter.ExactInputSingleParams memory params =
                            IV3SwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: WETH,
                fee: fee,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });
        amountOut = swapRouter.exactInputSingle(params);
        IWETH(WETH).withdraw(amountOut);
        return amountOut;
    }

}