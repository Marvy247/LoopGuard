// Looping Protocol ABIs

export const LOOPING_FACTORY_ABI = [
  {
    inputs: [
      { name: 'collateralAsset', type: 'address' },
      { name: 'borrowAsset', type: 'address' },
      { name: 'targetLTV', type: 'uint256' },
      { name: 'maxSlippage', type: 'uint256' },
    ],
    name: 'createPosition',
    outputs: [
      { name: 'callbackAddr', type: 'address' },
      { name: 'reactiveAddr', type: 'address' },
    ],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [{ name: 'user', type: 'address' }],
    name: 'getUserPositions',
    outputs: [{ name: '', type: 'address[]' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'position', type: 'address' }],
    name: 'getPositionDetails',
    outputs: [
      {
        components: [
          { name: 'callback', type: 'address' },
          { name: 'reactive', type: 'address' },
          { name: 'owner', type: 'address' },
          { name: 'collateralAsset', type: 'address' },
          { name: 'borrowAsset', type: 'address' },
          { name: 'targetLTV', type: 'uint256' },
          { name: 'createdAt', type: 'uint256' },
          { name: 'isActive', type: 'bool' },
        ],
        name: '',
        type: 'tuple',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getFlashLoanHelper',
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getTotalPositions',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'owner', type: 'address' },
      { indexed: true, name: 'callbackContract', type: 'address' },
      { indexed: true, name: 'reactiveContract', type: 'address' },
      { indexed: false, name: 'collateralAsset', type: 'address' },
      { indexed: false, name: 'borrowAsset', type: 'address' },
      { indexed: false, name: 'targetLTV', type: 'uint256' },
    ],
    name: 'PositionCreated',
    type: 'event',
  },
] as const;

export const LOOPING_CALLBACK_ABI = [
  {
    inputs: [{ name: 'initialAmount', type: 'uint256' }],
    name: 'executeLeverageLoop',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'unwindPosition',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getPositionDetails',
    outputs: [
      { name: 'totalCollateral', type: 'uint256' },
      { name: 'totalDebt', type: 'uint256' },
      { name: 'availableBorrow', type: 'uint256' },
      { name: 'currentLTV', type: 'uint256' },
      { name: 'healthFactor', type: 'uint256' },
      { name: 'loops', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: '_warningThreshold', type: 'uint256' },
      { name: '_dangerThreshold', type: 'uint256' },
    ],
    name: 'updateSafetyThresholds',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'owner',
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'collateralAsset',
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'borrowAsset',
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'targetLTV',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'warningThreshold',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'dangerThreshold',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'iteration', type: 'uint256' },
      { indexed: false, name: 'supplied', type: 'uint256' },
      { indexed: false, name: 'borrowed', type: 'uint256' },
      { indexed: false, name: 'swapped', type: 'uint256' },
    ],
    name: 'LoopExecuted',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: false, name: 'healthFactor', type: 'uint256' },
      { indexed: false, name: 'amountUnwound', type: 'uint256' },
    ],
    name: 'EmergencyUnwind',
    type: 'event',
  },
] as const;

export const LOOPING_REACTIVE_ABI = [
  {
    inputs: [],
    name: 'getMonitoringStatus',
    outputs: [
      { name: 'currentHealthFactor', type: 'uint256' },
      { name: 'lastBlock', type: 'uint256' },
      { name: 'alerts', type: 'uint256' },
      { name: 'isDanger', type: 'bool' },
      { name: 'isWarning', type: 'bool' },
      { name: 'isSafe', type: 'bool' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getCurrentPositionData',
    outputs: [
      { name: 'totalCollateral', type: 'uint256' },
      { name: 'totalDebt', type: 'uint256' },
      { name: 'availableBorrow', type: 'uint256' },
      { name: 'currentLTV', type: 'uint256' },
      { name: 'healthFactor', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'loopingCallback',
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'monitoredPosition',
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'warningThreshold',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'dangerThreshold',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: false, name: 'healthFactor', type: 'uint256' },
      { indexed: false, name: 'blockNumber', type: 'uint256' },
    ],
    name: 'HealthFactorChecked',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: false, name: 'healthFactor', type: 'uint256' },
      { indexed: false, name: 'totalCollateral', type: 'uint256' },
      { indexed: false, name: 'totalDebt', type: 'uint256' },
    ],
    name: 'EmergencyTriggered',
    type: 'event',
  },
] as const;

export const ERC20_ABI = [
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    name: 'approve',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    name: 'allowance',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;
