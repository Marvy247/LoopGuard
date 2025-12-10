// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/looping/LoopingCallback.sol";
import "../src/looping/LoopingReactive.sol";
import "../src/looping/LoopingFactory.sol";
import "../src/looping/FlashLoanHelper.sol";
import "../src/looping/IAaveV3Pool.sol";

/**
 * @title LoopingTest
 * @notice Comprehensive tests for the Intelligent Adaptive Looping Protocol
 */
contract LoopingTest is Test {
    
    LoopingFactory public factory;
    FlashLoanHelper public flashHelper;
    
    address public constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Sepolia
    address public constant UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // Sepolia
    address public constant WETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c; // Sepolia WETH
    address public constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8; // Sepolia USDC (example)
    
    uint256 constant REACTIVE_CHAIN_ID = 5318007;
    uint256 constant ORIGIN_CHAIN_ID = 11155111; // Sepolia
    
    address public user;
    address public loopingCallback;
    address public loopingReactive;
    
    function setUp() public {
        // Create test user
        user = makeAddr("user");
        vm.deal(user, 100 ether);
        
        // Deploy factory
        factory = new LoopingFactory(
            AAVE_POOL,
            UNISWAP_ROUTER,
            REACTIVE_CHAIN_ID
        );
        
        flashHelper = factory.flashLoanHelper();
        
        console.log("Factory deployed at:", address(factory));
        console.log("FlashLoanHelper deployed at:", address(flashHelper));
    }
    
    /**
     * @notice Test factory deployment
     */
    function test_FactoryDeployment() public {
        assertEq(factory.aavePool(), AAVE_POOL);
        assertEq(factory.uniswapRouter(), UNISWAP_ROUTER);
        assertEq(factory.getTotalPositions(), 0);
        assertTrue(address(flashHelper) != address(0));
    }
    
    /**
     * @notice Test position creation
     */
    function test_CreatePosition() public {
        vm.startPrank(user);
        
        uint256 targetLTV = 7000; // 70%
        uint256 maxSlippage = 300; // 3%
        
        (address callbackAddr, address reactiveAddr) = factory.createPosition{value: 1 ether}(
            WETH,
            USDC,
            targetLTV,
            maxSlippage
        );
        
        vm.stopPrank();
        
        // Verify addresses
        assertTrue(callbackAddr != address(0));
        assertTrue(reactiveAddr != address(0));
        
        // Verify position info
        LoopingFactory.PositionInfo memory info = factory.getPositionDetails(callbackAddr);
        assertEq(info.owner, user);
        assertEq(info.collateralAsset, WETH);
        assertEq(info.borrowAsset, USDC);
        assertEq(info.targetLTV, targetLTV);
        assertTrue(info.isActive);
        
        // Verify tracking
        address[] memory userPositions = factory.getUserPositions(user);
        assertEq(userPositions.length, 1);
        assertEq(userPositions[0], callbackAddr);
        assertEq(factory.getTotalPositions(), 1);
        
        console.log("Position created successfully!");
        console.log("Callback:", callbackAddr);
        console.log("Reactive:", reactiveAddr);
    }
    
    /**
     * @notice Test callback contract initialization
     */
    function test_CallbackInitialization() public {
        vm.prank(user);
        (address callbackAddr, ) = factory.createPosition{value: 1 ether}(
            WETH,
            USDC,
            7000,
            300
        );
        
        LoopingCallback callback = LoopingCallback(payable(callbackAddr));
        
        assertEq(callback.owner(), user);
        assertEq(callback.collateralAsset(), WETH);
        assertEq(callback.borrowAsset(), USDC);
        assertEq(callback.targetLTV(), 7000);
        assertEq(callback.maxSlippage(), 300);
        assertEq(callback.warningThreshold(), 2e18); // Default 2.0
        assertEq(callback.dangerThreshold(), 15e17); // Default 1.5
    }
    
    /**
     * @notice Test reactive contract initialization
     */
    function test_ReactiveInitialization() public {
        vm.prank(user);
        (, address reactiveAddr) = factory.createPosition{value: 1 ether}(
            WETH,
            USDC,
            7000,
            300
        );
        
        LoopingReactive reactive = LoopingReactive(payable(reactiveAddr));
        
        assertEq(reactive.aavePool(), AAVE_POOL);
        assertEq(reactive.warningThreshold(), 2e18);
        assertEq(reactive.dangerThreshold(), 15e17);
        assertEq(reactive.safeThreshold(), 3e18);
    }
    
    /**
     * @notice Test safety threshold updates
     */
    function test_UpdateSafetyThresholds() public {
        vm.prank(user);
        (address callbackAddr, ) = factory.createPosition{value: 1 ether}(
            WETH,
            USDC,
            7000,
            300
        );
        
        LoopingCallback callback = LoopingCallback(payable(callbackAddr));
        
        vm.prank(user);
        callback.updateSafetyThresholds(25e17, 17e17); // 2.5 and 1.7
        
        assertEq(callback.warningThreshold(), 25e17);
        assertEq(callback.dangerThreshold(), 17e17);
    }
    
    /**
     * @notice Test invalid threshold update (should revert)
     */
    function test_RevertWhen_InvalidThresholdUpdate() public {
        vm.prank(user);
        (address callbackAddr, ) = factory.createPosition{value: 1 ether}(
            WETH,
            USDC,
            7000,
            300
        );
        
        LoopingCallback callback = LoopingCallback(payable(callbackAddr));
        
        vm.prank(user);
        vm.expectRevert("Invalid thresholds");
        // Should fail: warning < danger
        callback.updateSafetyThresholds(15e17, 2e18);
    }
    
    /**
     * @notice Test multiple position creation
     */
    function test_MultiplePositions() public {
        vm.startPrank(user);
        
        // Create 3 positions
        factory.createPosition{value: 0.5 ether}(WETH, USDC, 6000, 300);
        factory.createPosition{value: 0.5 ether}(WETH, USDC, 7000, 300);
        factory.createPosition{value: 0.5 ether}(WETH, USDC, 7500, 300);
        
        vm.stopPrank();
        
        assertEq(factory.getTotalPositions(), 3);
        
        address[] memory userPositions = factory.getUserPositions(user);
        assertEq(userPositions.length, 3);
        
        console.log("Created 3 positions successfully!");
    }
    
    /**
     * @notice Test position deactivation
     */
    function test_DeactivatePosition() public {
        vm.prank(user);
        (address callbackAddr, ) = factory.createPosition{value: 1 ether}(
            WETH,
            USDC,
            7000,
            300
        );
        
        // Verify initially active
        assertTrue(factory.getPositionDetails(callbackAddr).isActive);
        
        // Deactivate
        vm.prank(user);
        factory.deactivatePosition(callbackAddr);
        
        // Verify deactivated
        assertFalse(factory.getPositionDetails(callbackAddr).isActive);
    }
    
    /**
     * @notice Test paginated position retrieval
     */
    function test_GetAllPositionsPaginated() public {
        vm.startPrank(user);
        
        // Create 5 positions
        for (uint i = 0; i < 5; i++) {
            factory.createPosition{value: 0.2 ether}(WETH, USDC, 7000, 300);
        }
        
        vm.stopPrank();
        
        // Get first 3
        address[] memory page1 = factory.getAllPositions(0, 3);
        assertEq(page1.length, 3);
        
        // Get next 2
        address[] memory page2 = factory.getAllPositions(3, 3);
        assertEq(page2.length, 2);
        
        // Get beyond limit
        address[] memory page3 = factory.getAllPositions(10, 3);
        assertEq(page3.length, 0);
        
        console.log("Pagination test passed!");
    }
    
    /**
     * @notice Test flash loan helper deployment
     */
    function test_FlashLoanHelper() public {
        assertEq(address(flashHelper.aavePool()), AAVE_POOL);
        assertEq(address(flashHelper.uniswapRouter()), UNISWAP_ROUTER);
        
        console.log("FlashLoanHelper configured correctly!");
    }
    
    /**
     * @notice Integration test - Create position and verify all components
     */
    function test_IntegrationFullSetup() public {
        console.log("\n=== INTEGRATION TEST ===");
        
        vm.startPrank(user);
        
        (address callbackAddr, address reactiveAddr) = factory.createPosition{value: 2 ether}(
            WETH,
            USDC,
            7000,
            300
        );
        
        vm.stopPrank();
        
        // Verify all components
        LoopingCallback callback = LoopingCallback(payable(callbackAddr));
        LoopingReactive reactive = LoopingReactive(payable(reactiveAddr));
        
        console.log("Position created");
        console.log("  Callback:", callbackAddr);
        console.log("  Reactive:", reactiveAddr);
        
        // Check callback config
        assertEq(callback.owner(), user);
        assertEq(address(callback.aavePool()), AAVE_POOL);
        assertEq(address(callback.uniswapRouter()), UNISWAP_ROUTER);
        console.log("Callback configured correctly");
        
        // Check reactive config
        assertEq(reactive.loopingCallback(), callbackAddr);
        assertEq(reactive.aavePool(), AAVE_POOL);
        assertEq(reactive.monitoredPosition(), callbackAddr);
        console.log("Reactive configured correctly");
        
        // Check factory tracking
        assertEq(factory.getTotalPositions(), 1);
        assertTrue(factory.getPositionDetails(callbackAddr).isActive);
        console.log("Factory tracking correct");
        
        // Check flash loan helper
        assertEq(factory.getFlashLoanHelper(), address(flashHelper));
        console.log("FlashLoanHelper available");
        
        console.log("\nALL INTEGRATION TESTS PASSED");
    }
}
