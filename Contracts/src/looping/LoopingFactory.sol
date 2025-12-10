// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LoopingCallback.sol';
import './LoopingReactive.sol';
import './FlashLoanHelper.sol';

/**
 * @title LoopingFactory
 * @notice Factory for deploying user-specific looping positions
 * @dev Manages deployment and tracking of all looping positions
 */
contract LoopingFactory {
    
    // Protocol addresses (set at deployment)
    address public immutable aavePool;
    address public immutable uniswapRouter;
    uint256 public immutable reactiveChainId;
    
    // Shared FlashLoanHelper (can be used by all positions)
    FlashLoanHelper public flashLoanHelper;
    
    // Tracking
    mapping(address => address[]) public userPositions;
    mapping(address => PositionInfo) public positionInfo;
    
    address[] public allPositions;
    
    struct PositionInfo {
        address callback;
        address reactive;
        address owner;
        address collateralAsset;
        address borrowAsset;
        uint256 targetLTV;
        uint256 createdAt;
        bool isActive;
    }
    
    // Events
    event PositionCreated(
        address indexed owner,
        address indexed callbackContract,
        address indexed reactiveContract,
        address collateralAsset,
        address borrowAsset,
        uint256 targetLTV
    );
    
    event FlashLoanHelperDeployed(address indexed helper);
    
    constructor(
        address _aavePool,
        address _uniswapRouter,
        uint256 _reactiveChainId
    ) {
        require(_aavePool != address(0), "Invalid Aave pool");
        require(_uniswapRouter != address(0), "Invalid router");
        
        aavePool = _aavePool;
        uniswapRouter = _uniswapRouter;
        reactiveChainId = _reactiveChainId;
        
        // Deploy shared flash loan helper
        flashLoanHelper = new FlashLoanHelper(_aavePool, _uniswapRouter);
        emit FlashLoanHelperDeployed(address(flashLoanHelper));
    }
    
    /**
     * @notice Create a new leveraged looping position
     * @param collateralAsset Asset to use as collateral
     * @param borrowAsset Asset to borrow
     * @param targetLTV Target loan-to-value in basis points (e.g., 7000 = 70%)
     * @param maxSlippage Maximum slippage tolerance in basis points
     * @return callbackAddr Address of the deployed LoopingCallback contract
     * @return reactiveAddr Address of the deployed LoopingReactive contract
     */
    function createPosition(
        address collateralAsset,
        address borrowAsset,
        uint256 targetLTV,
        uint256 maxSlippage
    ) external payable returns (address callbackAddr, address reactiveAddr) {
        require(collateralAsset != address(0), "Invalid collateral");
        require(borrowAsset != address(0), "Invalid borrow asset");
        require(targetLTV <= 8000, "LTV too high");
        require(maxSlippage <= 1000, "Slippage too high");
        
        // Deploy callback contract (receives value for initial funding)
        LoopingCallback callback = new LoopingCallback{value: msg.value / 2}(
            msg.sender, // Owner
            aavePool,
            uniswapRouter,
            collateralAsset,
            borrowAsset,
            address(0), // Reactive address set after deployment
            targetLTV,
            maxSlippage
        );
        
        callbackAddr = address(callback);
        
        // Deploy reactive contract (receives value for monitoring gas)
        LoopingReactive reactive = new LoopingReactive{value: msg.value / 2}(
            callbackAddr,
            aavePool,
            callbackAddr, // Monitor the callback contract's position
            block.chainid // Origin chain ID
        );
        
        reactiveAddr = address(reactive);
        
        // Store position info
        positionInfo[callbackAddr] = PositionInfo({
            callback: callbackAddr,
            reactive: reactiveAddr,
            owner: msg.sender,
            collateralAsset: collateralAsset,
            borrowAsset: borrowAsset,
            targetLTV: targetLTV,
            createdAt: block.timestamp,
            isActive: true
        });
        
        // Track positions
        userPositions[msg.sender].push(callbackAddr);
        allPositions.push(callbackAddr);
        
        emit PositionCreated(
            msg.sender,
            callbackAddr,
            reactiveAddr,
            collateralAsset,
            borrowAsset,
            targetLTV
        );
    }
    
    /**
     * @notice Get all positions for a user
     */
    function getUserPositions(address user) external view returns (address[] memory) {
        return userPositions[user];
    }
    
    /**
     * @notice Get position details
     */
    function getPositionDetails(address position) external view returns (PositionInfo memory) {
        return positionInfo[position];
    }
    
    /**
     * @notice Get total number of positions created
     */
    function getTotalPositions() external view returns (uint256) {
        return allPositions.length;
    }
    
    /**
     * @notice Get all positions (paginated)
     */
    function getAllPositions(uint256 offset, uint256 limit) 
        external 
        view 
        returns (address[] memory positions) 
    {
        uint256 total = allPositions.length;
        if (offset >= total) {
            return new address[](0);
        }
        
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        
        uint256 length = end - offset;
        positions = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
            positions[i] = allPositions[offset + i];
        }
    }
    
    /**
     * @notice Mark position as inactive
     */
    function deactivatePosition(address position) external {
        require(positionInfo[position].owner == msg.sender, "Not owner");
        positionInfo[position].isActive = false;
    }
    
    /**
     * @notice Get flash loan helper address
     */
    function getFlashLoanHelper() external view returns (address) {
        return address(flashLoanHelper);
    }
}
