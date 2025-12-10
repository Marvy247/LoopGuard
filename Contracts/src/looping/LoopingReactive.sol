// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../../lib/reactive-lib/src/interfaces/ISystemContract.sol';
import '../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol';
import '../../lib/reactive-lib/src/interfaces/IReactive.sol';
import './IAaveV3Pool.sol';

/**
 * @title LoopingReactive
 * @notice THE KILLER FEATURE: 24/7 Health Factor Monitoring & Auto-Protection
 * @dev Continuously monitors Aave positions and triggers protective deleveraging
 */
contract LoopingReactive is IReactive, AbstractPausableReactive {
    
    uint64 private constant GAS_LIMIT = 2000000;
    address public constant SERVICE = 0x0000000000000000000000000000000000fffFfF;
    
    // Chain and event configuration
    uint256 private immutable ORIGIN_CHAIN_ID;
    
    // Contract addresses
    address public immutable loopingCallback;
    address public immutable aavePool;
    address public immutable monitoredPosition;
    
    // Health factor thresholds (in 1e18 format, e.g., 2e18 = HF 2.0)
    uint256 public warningThreshold = 2e18;   // Trigger partial deleverage
    uint256 public dangerThreshold = 15e17;    // Trigger emergency deleverage
    uint256 public safeThreshold = 3e18;       // Consider position safe
    
    // Monitoring state
    uint256 public lastCheckedBlock;
    uint256 public lastHealthFactor;
    uint256 public alertCount;
    
    // Aave V3 event signatures
    // Supply: 0x2b627736bca15cd5381dcf80b0bf11fd197d01a037c52b927a881a10fb73ba61
    // Borrow: 0xb3d084820fb1a9decffb176436bd02558d15fac9b0ddfed8c465bc7359d7dce0  
    // Repay: 0xa534c8dbe71f871f9f3530e97a74601fea17b426cae02e1c5aee42c96c784051
    bytes32 private constant SUPPLY_TOPIC = 0x2b627736bca15cd5381dcf80b0bf11fd197d01a037c52b927a881a10fb73ba61;
    bytes32 private constant BORROW_TOPIC = 0xb3d084820fb1a9decffb176436bd02558d15fac9b0ddfed8c465bc7359d7dce0;
    bytes32 private constant REPAY_TOPIC = 0xa534c8dbe71f871f9f3530e97a74601fea17b426cae02e1c5aee42c96c784051;
    
    // Events
    event HealthFactorChecked(uint256 healthFactor, uint256 blockNumber);
    event WarningTriggered(uint256 healthFactor, uint256 totalCollateral, uint256 totalDebt);
    event EmergencyTriggered(uint256 healthFactor, uint256 totalCollateral, uint256 totalDebt);
    event SafeZoneRestored(uint256 healthFactor);
    event ThresholdsUpdated(uint256 warningThreshold, uint256 dangerThreshold);
    event MonitoringActive(address indexed position, address indexed callback);

    constructor(
        address _loopingCallback,
        address _aavePool,
        address _monitoredPosition,
        uint256 _originChainId
    ) payable {
        require(_loopingCallback != address(0), "Invalid callback");
        require(_aavePool != address(0), "Invalid Aave pool");
        require(_monitoredPosition != address(0), "Invalid position");
        
        loopingCallback = _loopingCallback;
        aavePool = _aavePool;
        monitoredPosition = _monitoredPosition;
        ORIGIN_CHAIN_ID = _originChainId;
        
        service = ISystemContract(payable(SERVICE));
        
        // Subscribe to Aave events for the monitored position
        if (!vm) {
            _subscribeToAaveEvents();
        }
        
        emit MonitoringActive(_monitoredPosition, _loopingCallback);
    }

    /**
     * @notice Subscribe to all relevant Aave events
     */
    function _subscribeToAaveEvents() internal {
        // Subscribe to Supply events
        service.subscribe(
            ORIGIN_CHAIN_ID,
            aavePool,
            uint256(SUPPLY_TOPIC),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        
        // Subscribe to Borrow events
        service.subscribe(
            ORIGIN_CHAIN_ID,
            aavePool,
            uint256(BORROW_TOPIC),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        
        // Subscribe to Repay events
        service.subscribe(
            ORIGIN_CHAIN_ID,
            aavePool,
            uint256(REPAY_TOPIC),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /**
     * @notice Get pausable subscriptions for AbstractPausableReactive
     */
    function getPausableSubscriptions() internal view override returns (Subscription[] memory) {
        Subscription[] memory subs = new Subscription[](3);
        
        subs[0] = Subscription(
            ORIGIN_CHAIN_ID,
            aavePool,
            uint256(SUPPLY_TOPIC),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        
        subs[1] = Subscription(
            ORIGIN_CHAIN_ID,
            aavePool,
            uint256(BORROW_TOPIC),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        
        subs[2] = Subscription(
            ORIGIN_CHAIN_ID,
            aavePool,
            uint256(REPAY_TOPIC),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        
        return subs;
    }

    /**
     * @notice THE CORE REACTIVE FUNCTION - Monitors and protects 24/7
     * @dev Called automatically when Aave events are emitted
     */
    function react(LogRecord calldata log) external vmOnly {
        // Update tracking
        lastCheckedBlock = log.block_number;
        
        // Query current health factor from Aave
        (
            uint256 totalCollateral,
            uint256 totalDebt,
            ,
            ,
            ,
            uint256 healthFactor
        ) = IAaveV3Pool(aavePool).getUserAccountData(monitoredPosition);
        
        lastHealthFactor = healthFactor;
        
        emit HealthFactorChecked(healthFactor, log.block_number);
        
        // Skip if no debt (no risk)
        if (totalDebt == 0) {
            return;
        }
        
        // CRITICAL PROTECTION LOGIC
        
        // 🔴 DANGER ZONE: Emergency deleverage needed
        if (healthFactor < dangerThreshold && healthFactor > 1e18) {
            alertCount++;
            emit EmergencyTriggered(healthFactor, totalCollateral, totalDebt);
            
            // Trigger emergency callback
            bytes memory payload = abi.encodeWithSignature(
                "callback(address)",
                address(this)
            );
            
            emit Callback(
                ORIGIN_CHAIN_ID,
                loopingCallback,
                GAS_LIMIT,
                payload
            );
        }
        // 🟡 WARNING ZONE: Partial deleverage recommended
        else if (healthFactor < warningThreshold && healthFactor >= dangerThreshold) {
            alertCount++;
            emit WarningTriggered(healthFactor, totalCollateral, totalDebt);
            
            // Trigger partial deleverage callback
            bytes memory payload = abi.encodeWithSignature(
                "callback(address)",
                address(this)
            );
            
            emit Callback(
                ORIGIN_CHAIN_ID,
                loopingCallback,
                GAS_LIMIT,
                payload
            );
        }
        // 🟢 SAFE ZONE: All good
        else if (healthFactor >= safeThreshold) {
            if (alertCount > 0) {
                emit SafeZoneRestored(healthFactor);
                alertCount = 0;
            }
        }
    }

    /**
     * @notice Manual health check (can be called permissionlessly)
     * @dev Useful for manual monitoring or cron-based checks
     */
    function manualHealthCheck() external {
        (
            uint256 totalCollateral,
            uint256 totalDebt,
            ,
            ,
            ,
            uint256 healthFactor
        ) = IAaveV3Pool(aavePool).getUserAccountData(monitoredPosition);
        
        lastHealthFactor = healthFactor;
        lastCheckedBlock = block.number;
        
        emit HealthFactorChecked(healthFactor, block.number);
        
        if (totalDebt == 0) return;
        
        // Trigger protection if needed
        if (healthFactor < dangerThreshold && healthFactor > 1e18) {
            emit EmergencyTriggered(healthFactor, totalCollateral, totalDebt);
            
            bytes memory payload = abi.encodeWithSignature(
                "callback(address)",
                address(this)
            );
            
            emit Callback(
                ORIGIN_CHAIN_ID,
                loopingCallback,
                GAS_LIMIT,
                payload
            );
        } else if (healthFactor < warningThreshold && healthFactor >= dangerThreshold) {
            emit WarningTriggered(healthFactor, totalCollateral, totalDebt);
            
            bytes memory payload = abi.encodeWithSignature(
                "callback(address)",
                address(this)
            );
            
            emit Callback(
                ORIGIN_CHAIN_ID,
                loopingCallback,
                GAS_LIMIT,
                payload
            );
        }
    }

    /**
     * @notice Update protection thresholds
     * @dev Can be called by monitored position owner
     */
    function updateThresholds(
        uint256 _warningThreshold,
        uint256 _dangerThreshold,
        uint256 _safeThreshold
    ) external {
        // In production, add access control
        require(_safeThreshold > _warningThreshold, "Safe must be > warning");
        require(_warningThreshold > _dangerThreshold, "Warning must be > danger");
        require(_dangerThreshold > 1e18, "Danger must be > 1.0");
        
        warningThreshold = _warningThreshold;
        dangerThreshold = _dangerThreshold;
        safeThreshold = _safeThreshold;
        
        emit ThresholdsUpdated(_warningThreshold, _dangerThreshold);
    }

    /**
     * @notice Get current monitoring status
     */
    function getMonitoringStatus() external view returns (
        uint256 currentHealthFactor,
        uint256 lastBlock,
        uint256 alerts,
        bool isDanger,
        bool isWarning,
        bool isSafe
    ) {
        currentHealthFactor = lastHealthFactor;
        lastBlock = lastCheckedBlock;
        alerts = alertCount;
        
        if (lastHealthFactor > 0) {
            isDanger = lastHealthFactor < dangerThreshold;
            isWarning = lastHealthFactor >= dangerThreshold && lastHealthFactor < warningThreshold;
            isSafe = lastHealthFactor >= safeThreshold;
        }
    }

    /**
     * @notice Get position data directly from Aave
     */
    function getCurrentPositionData() external view returns (
        uint256 totalCollateral,
        uint256 totalDebt,
        uint256 availableBorrow,
        uint256 currentLTV,
        uint256 healthFactor
    ) {
        (totalCollateral, totalDebt, availableBorrow, , currentLTV, healthFactor) 
            = IAaveV3Pool(aavePool).getUserAccountData(monitoredPosition);
    }

    receive() external payable override(AbstractPayer, IPayer) {
        // Accept payments for gas
    }
}
