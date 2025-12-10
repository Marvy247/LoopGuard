# 🛡️ LoopGuard - Deployed Contract Addresses

## Your Position's 24/7 Guardian
**Deployment Date**: December 10, 2024  
**Network**: Ethereum Sepolia Testnet  
**Transaction**: `0x47bcca8bf9dc2ee7580a628a46047d3aa38880962732bc52cee1c054145fe740`  
**Block**: 9808629

---

## Main Contracts

### LoopingFactory
**Address**: `0x05e2C54D348d9F0d8C40dF90cf15BFE8717Ee03f`  
**Etherscan**: https://sepolia.etherscan.io/address/0x05e2C54D348d9F0d8C40dF90cf15BFE8717Ee03f

**Purpose**: Factory contract for deploying user-specific leveraged looping positions

**Key Functions**:
- `createPosition()` - Deploy new position (callback + reactive contracts)
- `getUserPositions()` - Get all positions for a user
- `getPositionDetails()` - Get detailed info about a position

---

### FlashLoanHelper
**Address**: `0x90FCe00Bed1547f8ED43441D1E5C9cAEE47f4811`  
**Etherscan**: https://sepolia.etherscan.io/address/0x90FCe00Bed1547f8ED43441D1E5C9cAEE47f4811

**Purpose**: Enables one-transaction leverage using Aave flash loans

**Key Functions**:
- `executeFlashLeverage()` - Instant leverage in one transaction
- `executeFlashDeleverage()` - Instant position unwind

---

## Protocol Dependencies (Pre-deployed)

### Aave V3 Pool (Sepolia)
**Address**: `0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951`  
**Purpose**: Lending protocol for supply/borrow operations

### Uniswap V3 Router (Sepolia)
**Address**: `0xE592427A0AEce92De3Edee1F18E0157C05861564`  
**Purpose**: DEX for token swaps during looping

---

## Dynamic Contracts (User-Specific)

When you create a position via `factory.createPosition()`, two contracts are deployed:

### LoopingCallback
**Deployed to**: Origin chain (Sepolia)  
**Purpose**: Manages the leveraged position  
**Features**:
- Execute leverage loops
- Unwind positions
- Emergency protection

### LoopingReactive  
**Deployed to**: Reactive Network (Lasna)  
**Purpose**: 24/7 health factor monitoring  
**Features**:
- Subscribe to Aave events
- Monitor health factor continuously  
- Trigger automatic protection

---

## How to Use

### 1. Create a Position
```javascript
// Connect wallet to Sepolia
// Call factory.createPosition() with:
createPosition(
  collateralAsset,  // e.g., WETH
  borrowAsset,      // e.g., USDC  
  7000,             // 70% target LTV
  300               // 3% max slippage
) { value: 0.1 ether }  // Fund the contracts
```

### 2. Your Contracts Get Deployed
- ✅ LoopingCallback deployed to Sepolia
- ✅ LoopingReactive deployed to Reactive Network
- ✅ Both contracts linked and ready

### 3. Execute Leverage
- Approve tokens
- Call `callback.executeLeverageLoop(amount)`
- Position created with automatic 24/7 protection!

---

## Frontend Integration

Update `/app/src/config/looping.ts`:

```typescript
export const LOOPING_ADDRESSES = {
  11155111: {  // Sepolia
    factory: '0x05e2C54D348d9F0d8C40dF90cf15BFE8717Ee03f',
    flashHelper: '0x90FCe00Bed1547f8ED43441D1E5C9cAEE47f4811',
    aavePool: '0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951',
    uniswapRouter: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  },
};
```

---

## Verification

All contracts compiled with:
- **Solidity**: 0.8.28
- **Optimizer**: Enabled (200 runs)
- **Via IR**: Enabled

Contract sizes (all within limits):
- LoopingFactory: 23,383 bytes ✅
- FlashLoanHelper: 5,622 bytes ✅
- LoopingCallback: 7,956 bytes ✅
- LoopingReactive: 6,277 bytes ✅

---

## Support

- **GitHub**: https://github.com/yourusername/ReactFeed
- **Docs**: See `/LOOPING_PROTOCOL.md`
- **Tests**: All 11 tests passing ✅

---

**Deployed by**: 0xFCA0157a303d2134854d9cF4718901B6515b0696  
**Network**: Ethereum Sepolia (Chain ID: 11155111)  
**Reactive Network**: Lasna (Chain ID: 5318007)
