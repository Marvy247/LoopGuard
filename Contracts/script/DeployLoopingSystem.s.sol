// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/looping/LoopingFactory.sol";
import "../src/looping/FlashLoanHelper.sol";

/**
 * @title DeployLoopingSystem
 * @notice Deployment script for the Intelligent Adaptive Looping Protocol
 */
contract DeployLoopingSystem is Script {
    
    // Sepolia addresses
    address constant AAVE_POOL_SEPOLIA = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant UNISWAP_ROUTER_SEPOLIA = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    
    // Reactive network chain ID
    uint256 constant REACTIVE_CHAIN_ID = 5318007;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying Intelligent Adaptive Looping Protocol...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        
        // Deploy factory
        LoopingFactory factory = new LoopingFactory(
            AAVE_POOL_SEPOLIA,
            UNISWAP_ROUTER_SEPOLIA,
            REACTIVE_CHAIN_ID
        );
        
        console.log("\n=== DEPLOYMENT SUCCESSFUL ===");
        console.log("LoopingFactory deployed at:", address(factory));
        console.log("FlashLoanHelper deployed at:", address(factory.flashLoanHelper()));
        console.log("\nConfiguration:");
        console.log("- Aave Pool:", AAVE_POOL_SEPOLIA);
        console.log("- Uniswap Router:", UNISWAP_ROUTER_SEPOLIA);
        console.log("- Reactive Chain ID:", REACTIVE_CHAIN_ID);
        
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Create a test position using factory.createPosition()");
        console.log("3. Fund the position and execute leverage loop");
        console.log("4. Monitor health factor via reactive contract");
        
        vm.stopBroadcast();
    }
}
