// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/oracle/FeedProxy.sol";
import "../src/oracle/OracleCallback.sol";
import "../src/oracle/OracleReactive.sol";

contract DeployOracle is Script {
    
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address callbackProxyAddr = vm.envAddress("CALLBACK_PROXY_ADDR");
        
        // Origin chain config
        uint256 originChainId = vm.envUint("ORIGIN_CHAIN_ID");
        address originFeed = vm.envAddress("ORIGIN_FEED_ADDRESS");
        
        // Destination chain config
        uint256 destinationChainId = vm.envUint("DESTINATION_CHAIN_ID");
        
        // Oracle config
        uint8 decimals = uint8(vm.envUint("FEED_DECIMALS"));
        string memory description = vm.envString("FEED_DESCRIPTION");
        uint256 stalenessThreshold = vm.envUint("STALENESS_THRESHOLD");
        uint256 deviationThresholdBps = vm.envUint("DEVIATION_THRESHOLD_BPS");
        uint256 cronInterval = vm.envUint("CRON_INTERVAL");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy FeedProxy on destination chain
        console.log("Deploying FeedProxy on destination chain...");
        FeedProxy feedProxy = new FeedProxy(
            decimals,
            description,
            callbackProxyAddr,
            stalenessThreshold
        );
        console.log("FeedProxy deployed at:", address(feedProxy));
        
        // Deploy OracleCallback on destination chain
        console.log("Deploying OracleCallback on destination chain...");
        OracleCallback callback = new OracleCallback(
            callbackProxyAddr,
            address(feedProxy),
            block.chainid, // Reactive chain ID
            originFeed,
            originChainId,
            address(0) // No direct origin feed access for cross-chain (set if on same chain)
        );
        console.log("OracleCallback deployed at:", address(callback));
        
        // Update FeedProxy to accept updates from callback
        feedProxy.updateCallbackProxy(address(callback));
        console.log("FeedProxy callback proxy updated");
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("FeedProxy:", address(feedProxy));
        console.log("OracleCallback:", address(callback));
        console.log("\nNow deploy OracleReactive on Reactive Network with callback address:", address(callback));
    }
}

contract DeployReactive is Script {
    
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("REACTIVE_PRIVATE_KEY");
        
        // Origin chain config
        uint256 originChainId = vm.envUint("ORIGIN_CHAIN_ID");
        address originFeed = vm.envAddress("ORIGIN_FEED_ADDRESS");
        
        // Destination chain config
        uint256 destinationChainId = vm.envUint("DESTINATION_CHAIN_ID");
        address callbackContract = vm.envAddress("CALLBACK_CONTRACT_ADDRESS");
        
        // Oracle config
        uint8 decimals = uint8(vm.envUint("FEED_DECIMALS"));
        string memory description = vm.envString("FEED_DESCRIPTION");
        uint256 deviationThresholdBps = vm.envUint("DEVIATION_THRESHOLD_BPS");
        uint256 cronInterval = vm.envUint("CRON_INTERVAL");
        uint256 initialFunding = vm.envUint("INITIAL_FUNDING");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying OracleReactive on Reactive Network...");
        OracleReactive reactive = new OracleReactive{value: initialFunding}(
            originChainId,
            destinationChainId,
            originFeed,
            callbackContract,
            deviationThresholdBps,
            cronInterval,
            decimals,
            description
        );
        console.log("OracleReactive deployed at:", address(reactive));
        
        vm.stopBroadcast();
        
        console.log("\n=== Reactive Deployment Summary ===");
        console.log("OracleReactive:", address(reactive));
        console.log("Initial funding:", initialFunding);
        console.log("Monitoring origin feed:", originFeed);
        console.log("Sending updates to callback:", callbackContract);
    }
}
