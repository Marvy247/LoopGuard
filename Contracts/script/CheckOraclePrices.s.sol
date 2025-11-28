// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/oracle/IAggregatorV3.sol";
import "../src/oracle/OracleReactive.sol";

/// @title CheckOraclePrices
/// @notice Script to check and compare ETH/USD prices from Chainlink Sepolia and relayed Base Sepolia feed
contract CheckOraclePrices is Script {
    
    function run() external {
        // Load addresses from environment
        address originFeed = vm.envAddress("ORIGIN_FEED_ADDRESS");
        address feedProxyAddress = vm.envAddress("FEED_PROXY_ADDRESS");
        address reactiveAddress = vm.envAddress("REACTIVE_CONTRACT_ADDRESS");
        
        string memory originRpc = vm.envString("ORIGIN_RPC");
        string memory destinationRpc = vm.envString("DESTINATION_RPC");
        string memory reactiveRpc = vm.envString("REACTIVE_RPC");
        
        console.log("=== Chainlink ETH/USD Feed Status ===\n");
        
        // Check Origin Feed (Chainlink on Sepolia)
        console.log("1. ORIGIN CHAIN (Ethereum Sepolia)");
        console.log("   Feed Address:", originFeed);
        _checkFeed(originFeed, originRpc, "Chainlink");
        
        console.log("\n2. DESTINATION CHAIN (Base Sepolia)");
        console.log("   FeedProxy Address:", feedProxyAddress);
        _checkFeed(feedProxyAddress, destinationRpc, "FeedProxy");
        
        console.log("\n3. REACTIVE CONTRACT (Reactive Lasna)");
        console.log("   OracleReactive Address:", reactiveAddress);
        _checkReactive(reactiveAddress, reactiveRpc);
        
        console.log("\n===========================================");
    }
    
    function _checkFeed(address feedAddress, string memory rpc, string memory name) internal {
        // Get decimals
        string[] memory decInputs = new string[](5);
        decInputs[0] = "cast";
        decInputs[1] = "call";
        decInputs[2] = vm.toString(feedAddress);
        decInputs[3] = "decimals()";
        decInputs[4] = string.concat("--rpc-url=", rpc);
        
        bytes memory decResult = vm.ffi(decInputs);
        uint8 decimals = uint8(uint256(bytes32(decResult)));
        
        // Get description
        string[] memory descInputs = new string[](5);
        descInputs[0] = "cast";
        descInputs[1] = "call";
        descInputs[2] = vm.toString(feedAddress);
        descInputs[3] = "description()";
        descInputs[4] = string.concat("--rpc-url=", rpc);
        
        // Get latest round data
        string[] memory inputs = new string[](5);
        inputs[0] = "cast";
        inputs[1] = "call";
        inputs[2] = vm.toString(feedAddress);
        inputs[3] = "latestRoundData()";
        inputs[4] = string.concat("--rpc-url=", rpc);
        
        bytes memory result = vm.ffi(inputs);
        
        // Decode the result (roundId, answer, startedAt, updatedAt, answeredInRound)
        (uint80 roundId, int256 answer, , uint256 updatedAt, ) = abi.decode(
            result,
            (uint80, int256, uint256, uint256, uint80)
        );
        
        // Calculate price with decimals
        int256 priceInt = answer / int256(10 ** (decimals - 2)); // Get price with 2 decimals
        uint256 wholePart = uint256(priceInt) / 100;
        uint256 decimalPart = uint256(priceInt) % 100;
        
        console.log("   Feed Type:", name);
        console.log("   Description: ETH / USD");
        console.log("   Decimals:", uint256(decimals));
        console.log("   Round ID:", uint256(roundId));
        console.log("   Price: $%s.%s", vm.toString(wholePart), _padDecimals(decimalPart));
        console.log("   Raw Answer:", vm.toString(answer));
        console.log("   Last Updated:", vm.toString(updatedAt));
        
        // Calculate time since update
        uint256 timeSinceUpdate = block.timestamp - updatedAt;
        console.log("   Time Since Update:", vm.toString(timeSinceUpdate), "seconds");
    }
    
    function _checkReactive(address reactiveAddress, string memory rpc) internal {
        // Check balance
        string[] memory balInputs = new string[](4);
        balInputs[0] = "cast";
        balInputs[1] = "balance";
        balInputs[2] = vm.toString(reactiveAddress);
        balInputs[3] = string.concat("--rpc-url=", rpc);
        
        bytes memory balResult = vm.ffi(balInputs);
        uint256 balance = abi.decode(balResult, (uint256));
        
        // Check last reported price
        string[] memory priceInputs = new string[](5);
        priceInputs[0] = "cast";
        priceInputs[1] = "call";
        priceInputs[2] = vm.toString(reactiveAddress);
        priceInputs[3] = "lastReportedPrice()";
        priceInputs[4] = string.concat("--rpc-url=", rpc);
        
        bytes memory priceResult = vm.ffi(priceInputs);
        int256 lastPrice = abi.decode(priceResult, (int256));
        
        // Check deviation threshold
        string[] memory devInputs = new string[](5);
        devInputs[0] = "cast";
        devInputs[1] = "call";
        devInputs[2] = vm.toString(reactiveAddress);
        devInputs[3] = "DEVIATION_THRESHOLD_BPS()";
        devInputs[4] = string.concat("--rpc-url=", rpc);
        
        bytes memory devResult = vm.ffi(devInputs);
        uint256 deviationThreshold = abi.decode(devResult, (uint256));
        
        console.log("   Balance:", vm.toString(balance / 1e18), "REACT");
        console.log("   Last Reported Price:", vm.toString(lastPrice));
        console.log("   Deviation Threshold:", vm.toString(deviationThreshold), "basis points");
        
        if (balance < 0.1 ether) {
            console.log("   WARNING: Low balance! Consider refilling.");
        } else {
            console.log("   Status: Operational");
        }
    }
    
    function _padDecimals(uint256 decimals) internal pure returns (string memory) {
        if (decimals < 10) {
            return string.concat("0", vm.toString(decimals));
        }
        return vm.toString(decimals);
    }
}
