// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './IAaveV3Pool.sol';
import './IUniswapV3Router.sol';
import './IERC20.sol';
import './SafeERC20.sol';

/**
 * @title FlashLoanHelper
 * @notice Advanced feature: Execute entire leverage loop in ONE transaction using flash loans
 * @dev Uses Aave V3 flash loans to instantly achieve target leverage without multiple loops
 */
contract FlashLoanHelper is IFlashLoanSimpleReceiver {
    using SafeERC20 for IERC20;
    
    IAaveV3Pool public immutable aavePool;
    ISwapRouter public immutable uniswapRouter;
    
    address public owner;
    uint24 public constant UNISWAP_FEE = 3000; // 0.3%
    
    enum FlashLoanAction { LEVERAGE, DELEVERAGE }
    
    struct FlashLoanParams {
        FlashLoanAction action;
        address collateralAsset;
        address borrowAsset;
        uint256 userSuppliedAmount;
        uint256 targetLeverageMultiplier; // In 1e18 format, e.g., 3e18 = 3x
        uint256 maxSlippage;
        address user;
    }
    
    event FlashLeverageExecuted(
        address indexed user,
        uint256 flashAmount,
        uint256 finalCollateral,
        uint256 finalDebt,
        uint256 achievedLeverage
    );
    
    event FlashDeleverageExecuted(
        address indexed user,
        uint256 flashAmount,
        uint256 debtRepaid,
        uint256 collateralReturned
    );
    
    constructor(address _aavePool, address _uniswapRouter) {
        require(_aavePool != address(0), "Invalid Aave pool");
        require(_uniswapRouter != address(0), "Invalid router");
        
        owner = msg.sender;
        aavePool = IAaveV3Pool(_aavePool);
        uniswapRouter = ISwapRouter(_uniswapRouter);
    }
    
    /**
     * @notice Execute leveraged position in ONE transaction using flash loan
     * @param collateralAsset Asset to use as collateral (e.g., WETH)
     * @param borrowAsset Asset to borrow (e.g., USDC or same as collateral)
     * @param userSuppliedAmount Initial amount user is supplying
     * @param targetLeverageMultiplier Desired leverage (e.g., 3e18 = 3x)
     * @param maxSlippage Maximum slippage in basis points
     */
    function executeFlashLeverage(
        address collateralAsset,
        address borrowAsset,
        uint256 userSuppliedAmount,
        uint256 targetLeverageMultiplier,
        uint256 maxSlippage
    ) external {
        require(userSuppliedAmount > 0, "Invalid amount");
        require(targetLeverageMultiplier >= 1e18 && targetLeverageMultiplier <= 5e18, "Leverage must be 1-5x");
        require(maxSlippage <= 1000, "Slippage too high");
        
        // Transfer user's initial collateral
        IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), userSuppliedAmount);
        
        // Calculate flash loan amount needed to achieve target leverage
        // Formula: flashAmount = userSuppliedAmount * (leverageMultiplier - 1)
        uint256 flashAmount = (userSuppliedAmount * (targetLeverageMultiplier - 1e18)) / 1e18;
        
        // Encode params for callback
        FlashLoanParams memory params = FlashLoanParams({
            action: FlashLoanAction.LEVERAGE,
            collateralAsset: collateralAsset,
            borrowAsset: borrowAsset,
            userSuppliedAmount: userSuppliedAmount,
            targetLeverageMultiplier: targetLeverageMultiplier,
            maxSlippage: maxSlippage,
            user: msg.sender
        });
        
        bytes memory encodedParams = abi.encode(params);
        
        // Execute flash loan
        address[] memory assets = new address[](1);
        assets[0] = borrowAsset;
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashAmount;
        
        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 0; // 0 = no debt, must repay in same transaction
        
        aavePool.flashLoan(
            address(this),
            assets,
            amounts,
            interestRateModes,
            address(this),
            encodedParams,
            0
        );
    }
    
    /**
     * @notice Execute instant deleverage using flash loan
     * @param collateralAsset Asset used as collateral
     * @param borrowAsset Asset that was borrowed
     * @param repayAmount Amount of debt to repay
     */
    function executeFlashDeleverage(
        address collateralAsset,
        address borrowAsset,
        uint256 repayAmount
    ) external {
        require(repayAmount > 0, "Invalid amount");
        
        // Encode params for callback
        FlashLoanParams memory params = FlashLoanParams({
            action: FlashLoanAction.DELEVERAGE,
            collateralAsset: collateralAsset,
            borrowAsset: borrowAsset,
            userSuppliedAmount: repayAmount,
            targetLeverageMultiplier: 0,
            maxSlippage: 300, // 3% default
            user: msg.sender
        });
        
        bytes memory encodedParams = abi.encode(params);
        
        // Flash loan the repay amount
        address[] memory assets = new address[](1);
        assets[0] = borrowAsset;
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = repayAmount;
        
        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 0;
        
        aavePool.flashLoan(
            address(this),
            assets,
            amounts,
            interestRateModes,
            address(this),
            encodedParams,
            0
        );
    }
    
    /**
     * @notice Flash loan callback - executes the leveraging logic
     * @dev Called by Aave during flash loan execution
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(aavePool), "Only Aave pool");
        require(initiator == address(this), "Only this contract");
        
        FlashLoanParams memory flashParams = abi.decode(params, (FlashLoanParams));
        
        if (flashParams.action == FlashLoanAction.LEVERAGE) {
            _executeLeverageLogic(asset, amount, premium, flashParams);
        } else {
            _executeDeleverageLogic(asset, amount, premium, flashParams);
        }
        
        // Approve Aave to take back flash loan + premium
        uint256 totalDebt = amount + premium;
        IERC20(asset).safeApprove(address(aavePool), totalDebt);
        
        return true;
    }
    
    /**
     * @notice Internal leverage logic executed during flash loan
     */
    function _executeLeverageLogic(
        address asset,
        uint256 flashAmount,
        uint256 premium,
        FlashLoanParams memory params
    ) internal {
        // Now we have:
        // 1. User's initial collateral (already transferred)
        // 2. Flash loaned borrow asset
        
        uint256 totalBorrowAsset = flashAmount;
        uint256 totalCollateralToSupply = params.userSuppliedAmount;
        
        // If borrow asset != collateral, swap flash loaned amount to collateral
        if (params.borrowAsset != params.collateralAsset) {
            IERC20(params.borrowAsset).safeApprove(address(uniswapRouter), flashAmount);
            
            uint256 minOut = (flashAmount * (10000 - params.maxSlippage)) / 10000;
            
            ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: params.borrowAsset,
                tokenOut: params.collateralAsset,
                fee: UNISWAP_FEE,
                recipient: address(this),
                deadline: block.timestamp + 300,
                amountIn: flashAmount,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: 0
            });
            
            uint256 swappedCollateral = uniswapRouter.exactInputSingle(swapParams);
            totalCollateralToSupply += swappedCollateral;
        } else {
            // Same asset looping
            totalCollateralToSupply += flashAmount;
        }
        
        // Supply all collateral to Aave on behalf of user
        IERC20(params.collateralAsset).safeApprove(address(aavePool), totalCollateralToSupply);
        aavePool.supply(params.collateralAsset, totalCollateralToSupply, params.user, 0);
        
        // Borrow enough to repay flash loan + premium
        uint256 borrowAmount = flashAmount + premium;
        
        // Add a small buffer for safety
        borrowAmount = (borrowAmount * 101) / 100; // 1% buffer
        
        // User must borrow to repay the flash loan
        aavePool.borrow(params.borrowAsset, borrowAmount, 2, 0, params.user);
        
        // Transfer borrowed amount to this contract to repay flash loan
        IERC20(params.borrowAsset).safeTransferFrom(params.user, address(this), borrowAmount);
        
        // Get final position
        (uint256 finalCollateral, uint256 finalDebt, , , , ) = aavePool.getUserAccountData(params.user);
        
        uint256 achievedLeverage = finalCollateral > 0 ? (finalCollateral * 1e18) / params.userSuppliedAmount : 0;
        
        emit FlashLeverageExecuted(
            params.user,
            flashAmount,
            finalCollateral,
            finalDebt,
            achievedLeverage
        );
    }
    
    /**
     * @notice Internal deleverage logic executed during flash loan
     */
    function _executeDeleverageLogic(
        address asset,
        uint256 flashAmount,
        uint256 premium,
        FlashLoanParams memory params
    ) internal {
        // Use flash loaned borrow asset to repay user's debt
        IERC20(params.borrowAsset).safeApprove(address(aavePool), flashAmount);
        uint256 repaid = aavePool.repay(params.borrowAsset, flashAmount, 2, params.user);
        
        // Now user can withdraw collateral
        // Calculate how much collateral needed to repay flash loan + premium
        uint256 totalOwed = flashAmount + premium;
        
        // Withdraw collateral from user's position
        uint256 withdrawn = aavePool.withdraw(params.collateralAsset, type(uint256).max, address(this));
        
        // If collateral != borrow asset, swap to repay flash loan
        if (params.collateralAsset != params.borrowAsset) {
            IERC20(params.collateralAsset).safeApprove(address(uniswapRouter), withdrawn);
            
            ISwapRouter.ExactOutputSingleParams memory swapParams = ISwapRouter.ExactOutputSingleParams({
                tokenIn: params.collateralAsset,
                tokenOut: params.borrowAsset,
                fee: UNISWAP_FEE,
                recipient: address(this),
                deadline: block.timestamp + 300,
                amountOut: totalOwed,
                amountInMaximum: withdrawn,
                sqrtPriceLimitX96: 0
            });
            
            uint256 amountIn = uniswapRouter.exactOutputSingle(swapParams);
            
            // Return remaining collateral to user
            uint256 remaining = withdrawn - amountIn;
            if (remaining > 0) {
                IERC20(params.collateralAsset).safeTransfer(params.user, remaining);
            }
        } else {
            // Same asset - return excess to user
            uint256 remaining = withdrawn - totalOwed;
            if (remaining > 0) {
                IERC20(params.collateralAsset).safeTransfer(params.user, remaining);
            }
        }
        
        emit FlashDeleverageExecuted(params.user, flashAmount, repaid, withdrawn);
    }
    
    /**
     * @notice Emergency withdrawal function
     */
    function emergencyWithdraw(address token) external {
        require(msg.sender == owner, "Only owner");
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(owner, balance);
        }
    }
}
