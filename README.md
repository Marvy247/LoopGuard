# Reactivate

A reactive blockchain platform enabling automated cross-chain operations, smart contract automation, and oracle services using the Reactive Network.

## Overview

Reactivate is a comprehensive blockchain automation platform that leverages reactive programming patterns to enable:

- **Automated Account Funding**: Monitor and automatically refill contract balances
- **Debt Management**: Automatic debt payment for reactive contracts
- **Oracle Services**: Cross-chain price feed relay with deviation-based triggers
- **Developer Accounts**: Secure fund management with whitelist controls

## Architecture

### System Overview

```mermaid
graph TB
    subgraph "Frontend Layer"
        A[Next.js Web App]
        B[Web3 Provider]
        C[RainbowKit Wallet]
    end
    
    subgraph "Smart Contract Layer"
        D[Account Factory]
        E[Funder Factory]
        F[Debt Payer Factory]
        G[Oracle System]
    end
    
    subgraph "Reactive Network"
        H[Reactive Contracts]
        I[System Contract]
        J[Callback Handler]
    end
    
    subgraph "Core Contracts"
        K[Dev Account]
        L[Funder]
        M[Debt Payer]
        N[Oracle Reactive]
        O[Oracle Callback]
    end
    
    A --> B
    B --> C
    A --> D
    A --> E
    A --> F
    A --> G
    
    D --> K
    E --> L
    F --> M
    G --> N
    G --> O
    
    L --> H
    M --> H
    N --> H
    
    H --> I
    I --> J
    J --> L
    J --> M
    J --> O
    
    L --> K
    M --> I
```

### Funder Module Architecture

```mermaid
sequenceDiagram
    participant User
    participant DevAccount
    participant Funder
    participant Reactive
    participant SystemContract
    participant TargetContract
    
    User->>DevAccount: Deploy & Fund Account
    User->>Funder: Create Funder (via Factory)
    DevAccount->>Funder: Whitelist Funder
    
    loop Balance Monitoring
        Reactive->>TargetContract: Check Balance
        alt Balance <= Threshold
            Reactive->>SystemContract: Trigger Callback
            SystemContract->>Funder: Execute callback()
            Funder->>TargetContract: Transfer Funds
            Funder->>DevAccount: Request withdraw()
            DevAccount->>Funder: Transfer Refill Amount
        end
    end
```

### Oracle Module Architecture

```mermaid
sequenceDiagram
    participant OriginChain
    participant OracleFeed
    participant OracleReactive
    participant ReactiveNetwork
    participant OracleCallback
    participant DestinationChain
    
    OracleFeed->>OracleReactive: AnswerUpdated Event
    OracleReactive->>OracleReactive: Check Deviation Threshold
    
    alt Deviation > Threshold
        OracleReactive->>OracleReactive: Generate EIP-712 Signature
        OracleReactive->>ReactiveNetwork: Emit Callback
        ReactiveNetwork->>OracleCallback: Execute updatePrice()
        OracleCallback->>OracleCallback: Verify Signature
        OracleCallback->>DestinationChain: Update Price Feed
    end
    
    Note over OracleReactive,ReactiveNetwork: Also supports Cron-based polling
```

### Debt Payer Module Architecture

```mermaid
sequenceDiagram
    participant User
    participant DebtPayer
    participant DebtReactive
    participant SystemContract
    participant TargetContract
    
    User->>DebtPayer: Deploy DebtPayer (via Factory)
    User->>DebtReactive: Deploy DebtReactive (via Factory)
    User->>DebtPayer: Fund with ETH
    
    loop Debt Monitoring
        DebtReactive->>SystemContract: Subscribe to Events
        SystemContract->>DebtReactive: Debt Accumulated Event
        DebtReactive->>SystemContract: Trigger Callback
        SystemContract->>DebtPayer: Execute callback()
        DebtPayer->>TargetContract: Call coverDebt()
        TargetContract->>SystemContract: Pay Debt
    end
```

### Contract Hierarchy

```mermaid
classDiagram
    class AbstractCallback {
        +address service
        +callback()
        +authorizedSenderOnly()
    }
    
    class AbstractReactive {
        +ISystemContract service
        +react()
        +subscribe()
    }
    
    class DevAccount {
        +address owner
        +address admin
        +mapping whitelisted
        +whitelist()
        +withdraw()
    }
    
    class Funder {
        +address callbackReceiver
        +uint256 refillValue
        +uint256 refillThreshold
        +callback()
    }
    
    class FunderReactive {
        +address callbackContract
        +react()
    }
    
    class DebtPayer {
        +address callbackContract
        +callback()
    }
    
    class DebtReactive {
        +address debtPayer
        +react()
    }
    
    class OracleReactive {
        +address originFeed
        +uint256 deviationThreshold
        +react()
    }
    
    class OracleCallback {
        +address feedProxy
        +updatePrice()
    }
    
    AbstractCallback <|-- Funder
    AbstractCallback <|-- DebtPayer
    AbstractCallback <|-- OracleCallback
    AbstractReactive <|-- FunderReactive
    AbstractReactive <|-- DebtReactive
    AbstractReactive <|-- OracleReactive
    
    Funder --> DevAccount
    FunderReactive --> Funder
    DebtReactive --> DebtPayer
    OracleReactive --> OracleCallback
```

## Project Structure

```
Reactivate/
├── app/                          # Next.js Frontend Application
│   ├── src/
│   │   ├── app/                  # Next.js App Router
│   │   │   ├── page.tsx         # Landing page
│   │   │   ├── dashboard/       # User dashboard
│   │   │   ├── create-account/  # Account creation flow
│   │   │   └── api/             # API routes
│   │   ├── components/          # React components
│   │   │   ├── ui/              # UI components
│   │   │   ├── layout/          # Layout components
│   │   │   ├── oracle/          # Oracle-specific components
│   │   │   └── sections/        # Page sections
│   │   ├── config/              # Configuration files
│   │   ├── hooks/               # Custom React hooks
│   │   ├── lib/                 # Utility libraries
│   │   ├── providers/           # React context providers
│   │   └── types/               # TypeScript type definitions
│   └── package.json
│
└── Contracts/                    # Smart Contracts (Foundry)
    ├── src/
    │   ├── account/             # Account management contracts
    │   │   ├── devAccount.sol
    │   │   ├── accountFactory.sol
    │   │   ├── bridgeCallback.sol
    │   │   └── bridgeReactive.sol
    │   ├── funder/              # Auto-funding contracts
    │   │   ├── funder.sol
    │   │   ├── reactive.sol
    │   │   ├── funderFactory.sol
    │   │   └── reactiveFactory.sol
    │   ├── debtPayer/           # Debt management contracts
    │   │   ├── debtPayer.sol
    │   │   ├── debtReactive.sol
    │   │   ├── debtPayerFactory.sol
    │   │   └── debtReactiveFactory.sol
    │   └── oracle/              # Oracle relay contracts
    │       ├── OracleReactive.sol
    │       ├── OracleCallback.sol
    │       ├── FeedProxy.sol
    │       └── IAggregatorV3.sol
    ├── script/                  # Deployment scripts
    ├── test/                    # Contract tests
    └── foundry.toml
```

## Core Modules

### 1. Developer Account Module

**Purpose**: Secure fund management with access control

**Key Features**:
- Admin and owner role management
- Whitelist-based withdrawal system
- Factory pattern deployment
- Multi-contract fund distribution

**Contracts**:
- `DevAccount.sol`: Main account contract with access control
- `accountFactory.sol`: Factory for deploying accounts

### 2. Funder Module

**Purpose**: Automated balance monitoring and refilling

**Key Features**:
- Threshold-based balance monitoring
- Automatic fund transfers
- Dual contract support (callback + reactive)
- Integration with DevAccount

**Contracts**:
- `funder.sol`: Callback contract for fund distribution
- `reactive.sol`: Reactive contract for balance monitoring
- `funderFactory.sol`: Factory for funder deployment
- `reactiveFactory.sol`: Factory for reactive deployment

**Flow**:
1. Reactive contract monitors target contract balances
2. When balance drops below threshold, triggers callback
3. Funder contract receives callback and transfers funds
4. Funds sourced from whitelisted DevAccount

### 3. Debt Payer Module

**Purpose**: Automatic debt payment for reactive contracts

**Key Features**:
- Real-time debt monitoring
- Automatic debt clearing
- System contract integration
- Gas optimization

**Contracts**:
- `debtPayer.sol`: Callback contract for debt payment
- `debtReactive.sol`: Reactive contract for debt monitoring
- `debtPayerFactory.sol`: Factory for payer deployment
- `debtReactiveFactory.sol`: Factory for reactive deployment

**Flow**:
1. DebtReactive monitors system contract for debt accumulation
2. On debt detection, triggers callback to DebtPayer
3. DebtPayer calls `coverDebt()` on target contracts
4. Debt cleared from system contract

### 4. Oracle Module

**Purpose**: Cross-chain price feed relay with verification

**Key Features**:
- Event-driven price updates
- Deviation threshold filtering
- EIP-712 signature verification
- Cron-based polling fallback
- Multi-chain support

**Contracts**:
- `OracleReactive.sol`: Monitors origin chain price feeds
- `OracleCallback.sol`: Updates destination chain feeds
- `FeedProxy.sol`: Chainlink-compatible price feed interface
- `IAggregatorV3.sol`: Aggregator interface

**Flow**:
1. OracleReactive subscribes to AnswerUpdated events
2. On price update, checks deviation threshold
3. If deviation exceeds threshold, generates EIP-712 signature
4. Emits callback with price data and signature
5. OracleCallback verifies signature and updates local feed

## Technology Stack

### Frontend
- **Framework**: Next.js 15.5 (React 19)
- **Styling**: Tailwind CSS 4
- **Web3**: 
  - wagmi 2.16
  - viem 2.37
  - RainbowKit 2.2
  - ethers.js 6.15
- **State Management**: TanStack Query 5.87
- **UI**: lucide-react, react-hot-toast
- **Backend**: Firebase 12.3

### Smart Contracts
- **Framework**: Foundry (Forge, Cast, Anvil)
- **Language**: Solidity ^0.8.0
- **Libraries**: reactive-lib (Abstract contracts)

## Getting Started

### Prerequisites
- Node.js 18+
- Foundry
- MetaMask or compatible Web3 wallet

### Frontend Setup

```bash
cd app
npm install
cp .env.example .env
# Configure environment variables
npm run dev
```

The app will be available at `http://localhost:3000`

### Smart Contract Setup

```bash
cd Contracts
forge install
forge build
forge test
```

### Deploy Contracts

```bash
# Deploy account factory
forge script script/DeployAccountFactory.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>

# Deploy funder system
forge script script/DeployFunderSystem.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>

# Deploy oracle system
forge script script/DeployOracleSystem.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

## Environment Variables

### Frontend (.env)
```
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id
NEXT_PUBLIC_ACCOUNT_FACTORY_ADDRESS=0x...
NEXT_PUBLIC_FUNDER_FACTORY_ADDRESS=0x...
NEXT_PUBLIC_DEBT_PAYER_FACTORY_ADDRESS=0x...
NEXT_PUBLIC_ORACLE_ADDRESS=0x...
```

### Contracts (.env)
```
PRIVATE_KEY=your_private_key
RPC_URL=your_rpc_url
ETHERSCAN_API_KEY=your_api_key
```

## Key Concepts

### Reactive Network
A blockchain that enables smart contracts to react to events from other chains. Contracts subscribe to events and execute callbacks when conditions are met.

### Callback Pattern
Two-contract system where:
1. **Reactive Contract**: Monitors events and triggers callbacks
2. **Callback Contract**: Executes business logic on callback

### Factory Pattern
Standardized deployment system ensuring:
- Consistent contract initialization
- Upgradeable deployments
- Centralized management
- Event tracking

### Whitelisting
Security mechanism where:
- DevAccount controls fund access
- Only whitelisted contracts can withdraw
- Admin can add/remove contracts
- Prevents unauthorized fund drains

## Use Cases

1. **DApp Gas Tank**: Automatically refill smart contract gas balances
2. **Protocol Maintenance**: Keep protocol contracts funded
3. **Cross-chain Oracles**: Relay price feeds across chains
4. **Debt Management**: Automatic debt clearing for reactive services
5. **Account Abstraction**: Manage multiple contract balances from one account

## Security Considerations

- All factory contracts deploy with deterministic addresses
- Whitelisting prevents unauthorized withdrawals
- EIP-712 signatures prevent oracle manipulation
- Callback authorization restricts execution to system contract
- Deviation thresholds prevent unnecessary oracle updates

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write/update tests
5. Submit a pull request

## License

MIT License - See LICENSE file for details

## Links

- [Reactive Network Documentation](https://docs.reactive.network)
- [Foundry Documentation](https://book.getfoundry.sh)
- [Next.js Documentation](https://nextjs.org/docs)
- [RainbowKit Documentation](https://www.rainbowkit.com)

## Support

For questions and support:
- Open an issue on GitHub
- Contact the development team
- Join our Discord community
