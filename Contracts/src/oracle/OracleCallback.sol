// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';
import './FeedProxy.sol';
import './IAggregatorV3.sol';

contract OracleCallback is AbstractCallback {
    
    address public feedProxy;
    address public reactiveContract;
    
    // EIP-712 Domain for verification
    bytes32 private immutable DOMAIN_SEPARATOR;
    bytes32 private constant PRICE_UPDATE_TYPEHASH = 
        keccak256("PriceUpdate(address feedAddress,uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound)");
    
    uint256 public immutable REACTIVE_CHAIN_ID;
    address public immutable ORIGIN_FEED_ADDRESS;
    uint256 public immutable ORIGIN_CHAIN_ID;
    
    // For polling mechanism
    IAggregatorV3 public originFeed;
    
    event PriceUpdated(
        uint80 indexed roundId,
        int256 answer,
        uint256 updatedAt,
        bytes32 verificationHash
    );
    
    event UpdateFailed(
        uint80 roundId,
        string reason
    );
    
    error SignatureVerificationFailed();
    error Unauthorized();
    
    constructor(
        address callbackProxy_,
        address feedProxy_,
        uint256 reactiveChainId,
        address originFeedAddress,
        uint256 originChainId,
        address originFeedContract
    ) AbstractCallback(callbackProxy_) {
        feedProxy = feedProxy_;
        REACTIVE_CHAIN_ID = reactiveChainId;
        ORIGIN_FEED_ADDRESS = originFeedAddress;
        ORIGIN_CHAIN_ID = originChainId;
        
        // Set origin feed for polling (only if on same chain as this callback)
        if (originFeedContract != address(0)) {
            originFeed = IAggregatorV3(originFeedContract);
        }
        
        // Setup EIP-712 domain separator (must match reactive contract)
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ReactiveOracleRelay")),
                keccak256(bytes("1")),
                REACTIVE_CHAIN_ID,
                address(0) // Reactive contract address would be set here in production
            )
        );
    }
    
    function updatePrice(
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound,
        uint8 decimals,
        string memory description,
        bytes32 providedDigest
    ) external authorizedSenderOnly {
        // Verify EIP-712 signature
        bytes32 structHash = keccak256(
            abi.encode(
                PRICE_UPDATE_TYPEHASH,
                ORIGIN_FEED_ADDRESS,
                roundId,
                answer,
                startedAt,
                updatedAt,
                answeredInRound
            )
        );
        
        bytes32 expectedDigest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        
        if (expectedDigest != providedDigest) {
            revert SignatureVerificationFailed();
        }
        
        // Update the feed proxy
        try FeedProxy(feedProxy).updateRoundData(
            roundId,
            answer,
            startedAt,
            updatedAt,
            answeredInRound
        ) {
            emit PriceUpdated(roundId, answer, updatedAt, providedDigest);
        } catch Error(string memory reason) {
            emit UpdateFailed(roundId, reason);
        } catch {
            emit UpdateFailed(roundId, "Unknown error");
        }
    }
    
    function pollAndUpdate() external authorizedSenderOnly {
        // Query the origin Chainlink feed for latest round data
        // Note: This works when the origin feed is accessible from this chain
        // For cross-chain scenarios, this would need a bridge/relay mechanism
        
        require(address(originFeed) != address(0), "Origin feed not configured for polling");
        
        try originFeed.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            // Get feed metadata
            uint8 decimals = originFeed.decimals();
            string memory description = originFeed.description();
            
            // Update the feed proxy directly (no signature verification for polling)
            // This is safe because it's called only via authorized reactive callback
            try FeedProxy(feedProxy).updateRoundData(
                roundId,
                answer,
                startedAt,
                updatedAt,
                answeredInRound
            ) {
                emit PriceUpdated(roundId, answer, updatedAt, bytes32(0));
            } catch Error(string memory reason) {
                emit UpdateFailed(roundId, reason);
            } catch {
                emit UpdateFailed(roundId, "Unknown error");
            }
        } catch Error(string memory reason) {
            emit UpdateFailed(0, string(abi.encodePacked("Feed query failed: ", reason)));
        } catch {
            emit UpdateFailed(0, "Feed query failed");
        }
    }
    
    function pollRoundData(uint80 _roundId) external authorizedSenderOnly {
        // Query specific round data from origin feed (for audit/historical data)
        require(address(originFeed) != address(0), "Origin feed not configured for polling");
        
        try originFeed.getRoundData(_roundId) returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            // Update the feed proxy with historical data
            try FeedProxy(feedProxy).updateRoundData(
                roundId,
                answer,
                startedAt,
                updatedAt,
                answeredInRound
            ) {
                emit PriceUpdated(roundId, answer, updatedAt, bytes32(0));
            } catch Error(string memory reason) {
                emit UpdateFailed(roundId, reason);
            } catch {
                emit UpdateFailed(roundId, "Unknown error");
            }
        } catch Error(string memory reason) {
            emit UpdateFailed(_roundId, string(abi.encodePacked("Round query failed: ", reason)));
        } catch {
            emit UpdateFailed(_roundId, "Round query failed");
        }
    }
    
    function updateFeedProxy(address newFeedProxy) external {
        require(msg.sender == FeedProxy(feedProxy).owner(), "Not authorized");
        feedProxy = newFeedProxy;
    }
    
    receive() external payable override {
        // Accept ETH for gas refunds
    }
}
