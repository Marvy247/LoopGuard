// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../lib/reactive-lib/src/interfaces/ISystemContract.sol';
import '../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol';
import '../../lib/reactive-lib/src/interfaces/IReactive.sol';
import './IAggregatorV3.sol';

contract OracleReactive is IReactive, AbstractPausableReactive {
    
    uint64 private constant GAS_LIMIT = 2000000;
    address private constant SYSTEM_CONTRACT = 0x0000000000000000000000000000000000fffFfF;
    
    // EIP-712 Domain
    bytes32 private immutable DOMAIN_SEPARATOR;
    bytes32 private constant PRICE_UPDATE_TYPEHASH = 
        keccak256("PriceUpdate(address feedAddress,uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound)");
    
    uint256 public immutable ORIGIN_CHAIN_ID;
    uint256 public immutable DESTINATION_CHAIN_ID;
    
    address public immutable ORIGIN_FEED;
    address public callbackContract;
    
    // Feed metadata
    uint8 public immutable FEED_DECIMALS;
    string public feedDescription;
    
    // Event signatures
    uint256 private constant ANSWER_UPDATED_TOPIC = uint256(keccak256("AnswerUpdated(int256,uint256,uint256)"));
    uint256 private constant CRON_TOPIC = uint256(keccak256("Tick(uint256)"));
    
    // Deviation threshold (in basis points, e.g., 50 = 0.5%)
    uint256 public immutable DEVIATION_THRESHOLD_BPS;
    
    // Cron interval (in seconds)
    uint256 public immutable CRON_INTERVAL;
    
    // Last known price for deviation check
    int256 public lastReportedPrice;
    uint80 public lastReportedRound;
    
    event PriceUpdateTriggered(
        uint80 indexed roundId,
        int256 answer,
        uint256 updatedAt,
        string reason
    );
    
    event DeviationCheckFailed(
        int256 oldPrice,
        int256 newPrice,
        uint256 deviationBps
    );
    
    constructor(
        uint256 originChainId,
        uint256 destinationChainId,
        address originFeed,
        address callbackContract_,
        uint256 deviationThresholdBps,
        uint256 cronInterval,
        uint8 feedDecimals,
        string memory feedDescription_
    ) payable {
        ORIGIN_CHAIN_ID = originChainId;
        DESTINATION_CHAIN_ID = destinationChainId;
        ORIGIN_FEED = originFeed;
        callbackContract = callbackContract_;
        DEVIATION_THRESHOLD_BPS = deviationThresholdBps;
        CRON_INTERVAL = cronInterval;
        FEED_DECIMALS = feedDecimals;
        feedDescription = feedDescription_;
        
        service = ISystemContract(payable(SYSTEM_CONTRACT));
        
        // Setup EIP-712 domain separator
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ReactiveOracleRelay")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
        
        // Subscribe to AnswerUpdated events from origin feed using .call() for graceful failure
        bytes memory payload1 = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            ORIGIN_CHAIN_ID,
            ORIGIN_FEED,
            ANSWER_UPDATED_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result1,) = address(service).call(payload1);
        
        // Subscribe to Cron events for periodic polling (optional)
        bytes memory payload2 = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            block.chainid,
            address(0),
            CRON_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result2,) = address(service).call(payload2);
        
        // Set vm flag if both subscriptions failed
        if (!subscription_result1 && !subscription_result2) {
            vm = true;
        }
    }
    
    function getPausableSubscriptions() internal view override returns (Subscription[] memory) {
        Subscription[] memory result = new Subscription[](2);
        result[0] = Subscription(
            ORIGIN_CHAIN_ID,
            ORIGIN_FEED,
            ANSWER_UPDATED_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        result[1] = Subscription(
            block.chainid,
            address(0),
            CRON_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }
    
    function react(LogRecord calldata log) external vmOnly {
        if (log.topic_0 == ANSWER_UPDATED_TOPIC) {
            _handleAnswerUpdated(log);
        } else if (log.topic_0 == CRON_TOPIC) {
            _handleCronTick();
        }
    }
    
    function _handleAnswerUpdated(LogRecord calldata log) private {
        // Decode AnswerUpdated event: (int256 current, uint256 roundId, uint256 updatedAt)
        int256 answer = int256(uint256(log.topic_1));
        uint80 roundId = uint80(uint256(log.topic_2));
        uint256 updatedAt = uint256(log.topic_3);
        
        _triggerUpdate(roundId, answer, updatedAt, "EventTriggered");
    }
    
    function _handleCronTick() private {
        // On cron, we would query the origin chain via view calls (if supported)
        // For now, emit callback to trigger polling logic in callback contract
        bytes memory payload = abi.encodeWithSignature(
            "pollAndUpdate()"
        );
        
        emit Callback(
            DESTINATION_CHAIN_ID,
            callbackContract,
            GAS_LIMIT,
            payload
        );
    }
    
    function _triggerUpdate(
        uint80 roundId,
        int256 answer,
        uint256 updatedAt,
        string memory reason
    ) private {
        // Check deviation threshold
        if (lastReportedPrice != 0) {
            uint256 deviationBps = _calculateDeviationBps(lastReportedPrice, answer);
            if (deviationBps < DEVIATION_THRESHOLD_BPS) {
                emit DeviationCheckFailed(lastReportedPrice, answer, deviationBps);
                return; // Don't trigger update if deviation too small
            }
        }
        
        // Fetch full round data (in production, would use view call)
        uint256 startedAt = updatedAt; // Simplified
        uint80 answeredInRound = roundId;
        
        // Generate EIP-712 signature hash
        bytes32 structHash = keccak256(
            abi.encode(
                PRICE_UPDATE_TYPEHASH,
                ORIGIN_FEED,
                roundId,
                answer,
                startedAt,
                updatedAt,
                answeredInRound
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        
        bytes memory payload = abi.encodeWithSignature(
            "updatePrice(uint80,int256,uint256,uint256,uint80,uint8,string,bytes32)",
            roundId,
            answer,
            startedAt,
            updatedAt,
            answeredInRound,
            FEED_DECIMALS,
            feedDescription,
            digest
        );
        
        emit Callback(
            DESTINATION_CHAIN_ID,
            callbackContract,
            GAS_LIMIT,
            payload
        );
        
        lastReportedPrice = answer;
        lastReportedRound = roundId;
        
        emit PriceUpdateTriggered(roundId, answer, updatedAt, reason);
    }
    
    function _calculateDeviationBps(int256 oldPrice, int256 newPrice) private pure returns (uint256) {
        if (oldPrice == 0) return type(uint256).max;
        
        int256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        uint256 absDiff = uint256(diff);
        uint256 absOldPrice = uint256(oldPrice > 0 ? oldPrice : -oldPrice);
        
        return (absDiff * 10000) / absOldPrice;
    }
    
    receive() external payable override(AbstractPayer, IPayer) {}
}
