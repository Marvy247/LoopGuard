// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ISwapRouter
 * @notice Interface for Uniswap V3 SwapRouter
 */
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice Swaps `amountIn` of one token for as much as possible of another token
     * @param params The parameters necessary for the swap
     * @return amountOut The amount of the received token
     */
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice Swaps as little as possible of one token for `amountOut` of another token
     * @param params The parameters necessary for the swap
     * @return amountIn The amount of the input token
     */
    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        returns (uint256 amountIn);
}
