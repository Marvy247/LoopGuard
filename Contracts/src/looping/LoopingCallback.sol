// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';
import './IAaveV3Pool.sol';
import './IUniswapV3Router.sol';
import './IERC20.sol';
import './SafeERC20.sol';

/**
 * @title LoopingCallback
 * @notice Executes leveraged looping and unwinding operations on Aave V3
 * @dev Receives callbacks from LoopingReactive to perform automated operations
 */
contract LoopingCallback is AbstractCallback {
    using SafeERC20 for IERC20;

    address public constant SERVICE = 0x0000000000000000000000000000000000fffFfF;
    
    // Protocol addresses
    IAaveV3Pool public immutable aavePool;
    ISwapRouter public immutable uniswapRouter;
    
    // User position config
    address public owner;
    address public collateralAsset;  // e.g., WETH
    address public borrowAsset;      // e.g., USDC or same as collateral
    address public reactiveContract;
    
    // Safety parameters
    uint256 public targetLTV;              // Target LTV in basis points (e.g., 7000 = 70%)
    uint256 public maxSlippage;            // Max slippage in basis points (e.g., 300 = 3%)
    uint256 public warningThreshold;       // HF threshold for warning (e.g., 2e18 = 2.0)
    uint256 public dangerThreshold;        // HF threshold for danger (e.g., 15e17 = 1.5)
    
    // Loop parameters (set to 2 for testnet gas optimization)
    uint256 public maxLoopIterations = 2;  // Optimized for testnet demonstration
    uint24 public uniswapPoolFee = 3000;   // 0.3% pool fee
    
    // State tracking
    bool public isLooping;
    uint256 public currentLoopCount;
    
    // Events
    event LoopExecuted(uint256 indexed iteration, uint256 supplied, uint256 borrowed, uint256 swapped);
    event UnwindExecuted(uint256 indexed iteration, uint256 withdrawn, uint256 repaid);
    event EmergencyUnwind(uint256 healthFactor, uint256 amountUnwound);
    event PartialDeleverage(uint256 healthFactor, uint256 loopsUnwound);
    event PositionCreated(address indexed owner, address collateral, address borrow, uint256 targetLTV);
    event SafetyThresholdsUpdated(uint256 warningThreshold, uint256 dangerThreshold);

    constructor(
        address _owner,
        address _aavePool,
        address _uniswapRouter,
        address _collateralAsset,
        address _borrowAsset,
        address _reactiveContract,
        uint256 _targetLTV,
        uint256 _maxSlippage
    ) AbstractCallback(SERVICE) payable {
        require(_owner != address(0), "Invalid owner");
        require(_aavePool != address(0), "Invalid Aave pool");
        require(_uniswapRouter != address(0), "Invalid Uniswap router");
        require(_targetLTV <= 8000, "LTV too high"); // Max 80%
        require(_maxSlippage <= 1000, "Slippage too high"); // Max 10%
        
        owner = _owner;
        aavePool = IAaveV3Pool(_aavePool);
        uniswapRouter = ISwapRouter(_uniswapRouter);
        collateralAsset = _collateralAsset;
        borrowAsset = _borrowAsset;
        reactiveContract = _reactiveContract;
        targetLTV = _targetLTV;
        maxSlippage = _maxSlippage;
        
        // Set default safety thresholds
        warningThreshold = 2e18;   // HF 2.0
        dangerThreshold = 15e17;    // HF 1.5
        
        emit PositionCreated(owner, _collateralAsset, _borrowAsset, _targetLTV);
    }

    /**
     * @notice Main callback function triggered by reactive contract
     * @param sender The sender address from reactive network
     */
    function callback(address sender) external authorizedSenderOnly rvmIdOnly(sender) {
        // Decode the action from the callback (would be passed in real implementation)
        // For now, check health factor and take appropriate action
        
        (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(address(this));
        
        if (healthFactor < dangerThreshold && healthFactor > 1e18) {
            // Emergency deleverage
            _emergencyDeleverage();
        } else if (healthFactor < warningThreshold && healthFactor >= dangerThreshold) {
            // Partial deleverage
            _partialDeleverage();
        }
    }

    /**
     * @notice Execute leveraged looping to reach target LTV
     * @param initialAmount Initial amount of collateral to supply
     */
    function executeLeverageLoop(uint256 initialAmount) external {
        require(msg.sender == owner, "Only owner");
        require(!isLooping, "Already looping");
        require(initialAmount > 0, "Invalid amount");
        
        isLooping = true;
        
        // Transfer initial collateral from owner
        IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), initialAmount);
        
        // Approve Aave to spend collateral
        IERC20(collateralAsset).safeApprove(address(aavePool), initialAmount);
        
        // Supply initial collateral
        aavePool.supply(collateralAsset, initialAmount, address(this), 0);
        
        // Execute loops
        for (uint256 i = 0; i < maxLoopIterations; i++) {
            currentLoopCount = i + 1;
            
            // Get current position
            (uint256 totalCollateral, uint256 totalDebt, uint256 availableBorrow, , uint256 ltv, uint256 healthFactor) 
                = aavePool.getUserAccountData(address(this));
            
            // Check if we've reached target LTV or can't borrow more
            uint256 currentLTVBps = totalDebt > 0 ? (totalDebt * 10000) / totalCollateral : 0;
            if (currentLTVBps >= targetLTV || availableBorrow < 100 || healthFactor < 15e17) {
                break;
            }
            
            // Calculate borrow amount (conservative approach)
            uint256 borrowAmount = _calculateOptimalBorrow(totalCollateral, totalDebt, availableBorrow);
            if (borrowAmount == 0) break;
            
            // Execute single loop iteration
            _executeSingleLoop(borrowAmount);
        }
        
        isLooping = false;
    }

    /**
     * @notice Execute a single loop iteration: borrow -> swap -> supply
     * @param borrowAmount Amount to borrow
     */
    function _executeSingleLoop(uint256 borrowAmount) internal {
        // 1. Borrow asset from Aave
        aavePool.borrow(borrowAsset, borrowAmount, 2, 0, address(this)); // Variable rate
        
        uint256 swappedAmount = borrowAmount;
        
        // 2. If borrow asset != collateral asset, swap on Uniswap
        if (borrowAsset != collateralAsset) {
            IERC20(borrowAsset).safeApprove(address(uniswapRouter), borrowAmount);
            
            uint256 minAmountOut = _calculateMinAmountOut(borrowAmount);
            
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: borrowAsset,
                tokenOut: collateralAsset,
                fee: uniswapPoolFee,
                recipient: address(this),
                deadline: block.timestamp + 300, // 5 minutes
                amountIn: borrowAmount,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0
            });
            
            swappedAmount = uniswapRouter.exactInputSingle(params);
        }
        
        // 3. Supply swapped collateral back to Aave
        IERC20(collateralAsset).safeApprove(address(aavePool), swappedAmount);
        aavePool.supply(collateralAsset, swappedAmount, address(this), 0);
        
        emit LoopExecuted(currentLoopCount, swappedAmount, borrowAmount, swappedAmount);
    }

    /**
     * @notice Unwind the entire leveraged position
     */
    function unwindPosition() external {
        require(msg.sender == owner, "Only owner");
        
        _fullUnwind();
    }

    /**
     * @notice Emergency deleverage when health factor is dangerously low
     */
    function _emergencyDeleverage() internal {
        (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(address(this));
        
        // Unwind enough loops to reach safe HF (target: 2.5)
        uint256 loopsToUnwind = currentLoopCount > 0 ? (currentLoopCount * 60) / 100 : 1; // Unwind 60%
        
        for (uint256 i = 0; i < loopsToUnwind; i++) {
            _executeSingleUnwind();
            
            // Check if we've reached safe zone
            (, , , , , uint256 newHF) = aavePool.getUserAccountData(address(this));
            if (newHF >= 25e17) break; // HF 2.5
        }
        
        emit EmergencyUnwind(healthFactor, loopsToUnwind);
    }

    /**
     * @notice Partial deleverage when health factor is in warning zone
     */
    function _partialDeleverage() internal {
        (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(address(this));
        
        // Unwind 20% of loops
        uint256 loopsToUnwind = currentLoopCount > 0 ? (currentLoopCount * 20) / 100 : 1;
        if (loopsToUnwind == 0) loopsToUnwind = 1;
        
        for (uint256 i = 0; i < loopsToUnwind; i++) {
            _executeSingleUnwind();
        }
        
        emit PartialDeleverage(healthFactor, loopsToUnwind);
    }

    /**
     * @notice Full position unwind
     */
    function _fullUnwind() internal {
        (uint256 totalCollateral, uint256 totalDebt, , , , ) = aavePool.getUserAccountData(address(this));
        
        require(totalCollateral > 0 || totalDebt > 0, "No position to unwind");
        
        // Unwind all loops
        while (totalDebt > 0) {
            _executeSingleUnwind();
            
            (, totalDebt, , , , ) = aavePool.getUserAccountData(address(this));
            
            // Safety check to prevent infinite loop
            if (totalDebt < 100) {
                // Dust amount, handle separately if needed
                break;
            }
        }
        
        // Withdraw remaining collateral
        uint256 remainingCollateral = IERC20(collateralAsset).balanceOf(address(this));
        if (remainingCollateral > 0) {
            aavePool.withdraw(collateralAsset, type(uint256).max, owner);
        }
    }

    /**
     * @notice Execute single unwind iteration: withdraw -> swap -> repay
     */
    function _executeSingleUnwind() internal {
        (uint256 totalCollateral, uint256 totalDebt, , , , ) = aavePool.getUserAccountData(address(this));
        
        if (totalDebt == 0) return;
        
        // Calculate safe withdrawal amount (10% of collateral per iteration)
        uint256 withdrawAmount = (totalCollateral * 10) / 100;
        
        // 1. Withdraw collateral
        uint256 withdrawn = aavePool.withdraw(collateralAsset, withdrawAmount, address(this));
        
        uint256 repayAmount = withdrawn;
        
        // 2. If collateral != borrow asset, swap to borrow asset
        if (collateralAsset != borrowAsset) {
            IERC20(collateralAsset).safeApprove(address(uniswapRouter), withdrawn);
            
            uint256 minAmountOut = _calculateMinAmountOut(withdrawn);
            
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: collateralAsset,
                tokenOut: borrowAsset,
                fee: uniswapPoolFee,
                recipient: address(this),
                deadline: block.timestamp + 300,
                amountIn: withdrawn,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0
            });
            
            repayAmount = uniswapRouter.exactInputSingle(params);
        }
        
        // 3. Repay debt
        IERC20(borrowAsset).safeApprove(address(aavePool), repayAmount);
        uint256 repaid = aavePool.repay(borrowAsset, repayAmount, 2, address(this));
        
        if (currentLoopCount > 0) currentLoopCount--;
        
        emit UnwindExecuted(currentLoopCount, withdrawn, repaid);
    }

    /**
     * @notice Calculate optimal borrow amount for next loop
     */
    function _calculateOptimalBorrow(
        uint256 totalCollateral,
        uint256 totalDebt,
        uint256 availableBorrow
    ) internal view returns (uint256) {
        // Target additional debt to reach target LTV
        uint256 targetTotalDebt = (totalCollateral * targetLTV) / 10000;
        
        if (targetTotalDebt <= totalDebt) return 0;
        
        uint256 additionalDebt = targetTotalDebt - totalDebt;
        
        // Take the minimum of what we want and what's available
        // Also apply a safety margin (90% of available)
        uint256 safeAvailable = (availableBorrow * 90) / 100;
        
        return additionalDebt < safeAvailable ? additionalDebt : safeAvailable;
    }

    /**
     * @notice Calculate minimum output amount accounting for slippage
     */
    function _calculateMinAmountOut(uint256 amountIn) internal view returns (uint256) {
        // In production, would use price oracle
        // For now, apply slippage directly (assuming 1:1 for same asset loops)
        return (amountIn * (10000 - maxSlippage)) / 10000;
    }

    /**
     * @notice Update safety thresholds
     */
    function updateSafetyThresholds(uint256 _warningThreshold, uint256 _dangerThreshold) external {
        require(msg.sender == owner, "Only owner");
        require(_warningThreshold > _dangerThreshold, "Invalid thresholds");
        require(_dangerThreshold > 1e18, "Danger threshold too low");
        
        warningThreshold = _warningThreshold;
        dangerThreshold = _dangerThreshold;
        
        emit SafetyThresholdsUpdated(_warningThreshold, _dangerThreshold);
    }

    /**
     * @notice Get current position details
     */
    function getPositionDetails() external view returns (
        uint256 totalCollateral,
        uint256 totalDebt,
        uint256 availableBorrow,
        uint256 currentLTV,
        uint256 healthFactor,
        uint256 loops
    ) {
        (totalCollateral, totalDebt, availableBorrow, , currentLTV, healthFactor) 
            = aavePool.getUserAccountData(address(this));
        loops = currentLoopCount;
    }

    /**
     * @notice Emergency withdrawal (only if no debt)
     */
    function emergencyWithdraw() external {
        require(msg.sender == owner, "Only owner");
        
        (, uint256 totalDebt, , , , ) = aavePool.getUserAccountData(address(this));
        require(totalDebt == 0, "Must repay debt first");
        
        aavePool.withdraw(collateralAsset, type(uint256).max, owner);
    }

    receive() external payable override {}
}
