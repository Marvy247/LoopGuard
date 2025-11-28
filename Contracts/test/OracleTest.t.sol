// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/oracle/FeedProxy.sol";
import "../src/oracle/OracleCallback.sol";
import "../src/oracle/IAggregatorV3.sol";

contract MockCallbackProxy {
    address public authorizedSender;
    
    constructor(address _authorizedSender) {
        authorizedSender = _authorizedSender;
    }
    
    function rvmId(address sender) external view returns (address) {
        return authorizedSender;
    }
}

contract OracleTest is Test {
    FeedProxy public feedProxy;
    OracleCallback public callback;
    MockCallbackProxy public callbackProxy;
    
    address public owner = address(this);
    address public user = address(0x1234);
    
    uint8 constant DECIMALS = 8;
    string constant DESCRIPTION = "ETH/USD";
    uint256 constant STALENESS_THRESHOLD = 3600; // 1 hour
    uint256 constant REACTIVE_CHAIN_ID = 1;
    address constant ORIGIN_FEED = address(0x5555);
    uint256 constant ORIGIN_CHAIN_ID = 11155111; // Sepolia
    
    event RoundUpdated(
        uint80 indexed roundId,
        int256 answer,
        uint256 updatedAt,
        address indexed updater
    );
    
    event CircuitBreakerTriggered(
        uint80 roundId,
        int256 oldAnswer,
        int256 newAnswer,
        uint256 deviationBps
    );
    
    function setUp() public {
        // Deploy mock callback proxy
        callbackProxy = new MockCallbackProxy(address(this));
        
        // Deploy FeedProxy
        feedProxy = new FeedProxy(
            DECIMALS,
            DESCRIPTION,
            address(callbackProxy),
            STALENESS_THRESHOLD
        );
        
        // Deploy OracleCallback
        callback = new OracleCallback(
            address(callbackProxy),
            address(feedProxy),
            REACTIVE_CHAIN_ID,
            ORIGIN_FEED,
            ORIGIN_CHAIN_ID,
            address(0) // No origin feed contract for testing
        );
        
        // Update FeedProxy to accept updates from callback
        feedProxy.updateCallbackProxy(address(callback));
    }
    
    function testDeployment() public {
        assertEq(feedProxy.decimals(), DECIMALS);
        assertEq(feedProxy.description(), DESCRIPTION);
        assertEq(feedProxy.version(), 1);
        assertEq(feedProxy.owner(), owner);
    }
    
    function testUpdateRoundData() public {
        uint80 roundId = 1;
        int256 answer = 2000_00000000; // $2000.00
        uint256 startedAt = block.timestamp;
        uint256 updatedAt = block.timestamp;
        uint80 answeredInRound = 1;
        
        vm.expectEmit(true, false, false, true);
        emit RoundUpdated(roundId, answer, updatedAt, address(this));
        
        vm.prank(address(callback));
        feedProxy.updateRoundData(roundId, answer, startedAt, updatedAt, answeredInRound);
        
        (
            uint80 returnedRoundId,
            int256 returnedAnswer,
            uint256 returnedStartedAt,
            uint256 returnedUpdatedAt,
            uint80 returnedAnsweredInRound
        ) = feedProxy.latestRoundData();
        
        assertEq(returnedRoundId, roundId);
        assertEq(returnedAnswer, answer);
        assertEq(returnedStartedAt, startedAt);
        assertEq(returnedUpdatedAt, updatedAt);
        assertEq(returnedAnsweredInRound, answeredInRound);
    }
    
    function testGetRoundData() public {
        // Add first round
        vm.prank(address(callback));
        feedProxy.updateRoundData(1, 2000_00000000, block.timestamp, block.timestamp, 1);
        
        // Add second round
        vm.prank(address(callback));
        feedProxy.updateRoundData(2, 2100_00000000, block.timestamp, block.timestamp, 2);
        
        (
            uint80 roundId,
            int256 answer,
            ,
            ,
            
        ) = feedProxy.getRoundData(1);
        
        assertEq(roundId, 1);
        assertEq(answer, 2000_00000000);
        
        (roundId, answer, , , ) = feedProxy.getRoundData(2);
        assertEq(roundId, 2);
        assertEq(answer, 2100_00000000);
    }
    
    function testRevertOnStaleData() public {
        uint80 roundId = 1;
        int256 answer = 2000_00000000;
        
        // Warp time forward first, then set old timestamp
        vm.warp(block.timestamp + STALENESS_THRESHOLD + 200);
        uint256 staleUpdatedAt = block.timestamp - STALENESS_THRESHOLD - 100;
        
        vm.expectRevert();
        vm.prank(address(callback));
        feedProxy.updateRoundData(roundId, answer, staleUpdatedAt, staleUpdatedAt, 1);
    }
    
    function testRevertOnInvalidRoundId() public {
        // Add first round
        vm.prank(address(callback));
        feedProxy.updateRoundData(2, 2000_00000000, block.timestamp, block.timestamp, 2);
        
        // Try to add round with lower ID
        vm.expectRevert();
        vm.prank(address(callback));
        feedProxy.updateRoundData(1, 2100_00000000, block.timestamp, block.timestamp, 1);
    }
    
    function testCircuitBreakerOnLargeDeviation() public {
        // Add first round
        vm.prank(address(callback));
        feedProxy.updateRoundData(1, 2000_00000000, block.timestamp, block.timestamp, 1);
        
        // Try to add round with >20% deviation (should fail)
        int256 largeDeviationPrice = 2500_00000000; // +25%
        
        vm.expectRevert();
        vm.prank(address(callback));
        feedProxy.updateRoundData(2, largeDeviationPrice, block.timestamp, block.timestamp, 2);
    }
    
    function testCircuitBreakerWithinThreshold() public {
        // Add first round
        vm.prank(address(callback));
        feedProxy.updateRoundData(1, 2000_00000000, block.timestamp, block.timestamp, 1);
        
        // Add round with <20% deviation (should succeed)
        int256 acceptablePrice = 2300_00000000; // +15%
        
        vm.prank(address(callback));
        feedProxy.updateRoundData(2, acceptablePrice, block.timestamp, block.timestamp, 2);
        
        (, int256 answer, , , ) = feedProxy.latestRoundData();
        assertEq(answer, acceptablePrice);
    }
    
    function testUnauthorizedUpdate() public {
        vm.expectRevert();
        vm.prank(user);
        feedProxy.updateRoundData(1, 2000_00000000, block.timestamp, block.timestamp, 1);
    }
    
    function testPauseUnpause() public {
        feedProxy.setPaused(true);
        assertTrue(feedProxy.paused());
        
        vm.expectRevert();
        vm.prank(address(callback));
        feedProxy.updateRoundData(1, 2000_00000000, block.timestamp, block.timestamp, 1);
        
        feedProxy.setPaused(false);
        assertFalse(feedProxy.paused());
        
        vm.prank(address(callback));
        feedProxy.updateRoundData(1, 2000_00000000, block.timestamp, block.timestamp, 1);
    }
    
    function testFuzzPriceUpdates(uint80 roundId, int256 price) public {
        // Bound inputs instead of assume to avoid rejections
        roundId = uint80(bound(uint256(roundId), 1, 50)); // Reduced max for gas
        price = int256(bound(uint256(int256(price)), 1500_00000000, 2500_00000000)); // $1500 to $2500
        
        for (uint80 i = 1; i <= roundId; i++) {
            // Small increments to stay within circuit breaker (20%)
            int256 adjustedPrice = price + int256(uint256(i) * 10000000); // $10 increments
            
            // Check if deviation is acceptable
            if (i > 1) {
                (,int256 lastPrice,,,) = feedProxy.latestRoundData();
                uint256 deviation = _calculateDeviationBps(lastPrice, adjustedPrice);
                if (deviation > 1500) break; // Stop if approaching circuit breaker
            }
            
            vm.prank(address(callback));
            feedProxy.updateRoundData(i, adjustedPrice, block.timestamp, block.timestamp, i);
        }
        
        // Check at least some rounds were added
        assertTrue(feedProxy.latestRound() > 0);
    }
    
    function _calculateDeviationBps(int256 oldPrice, int256 newPrice) private pure returns (uint256) {
        if (oldPrice == 0) return 0;
        int256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        uint256 absDiff = uint256(diff);
        uint256 absOldPrice = uint256(oldPrice > 0 ? oldPrice : -oldPrice);
        return (absDiff * 10000) / absOldPrice;
    }
}
