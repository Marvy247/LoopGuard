// Looping Protocol Configuration
// Deployed: December 10, 2024
// Network: Ethereum Sepolia Testnet
// Tx: 0x47bcca8bf9dc2ee7580a628a46047d3aa38880962732bc52cee1c054145fe740

export const LOOPING_ADDRESSES = {
  // Sepolia Testnet
  11155111: {
    factory: '0x05e2C54D348d9F0d8C40dF90cf15BFE8717Ee03f' as `0x${string}`, // ✅ DEPLOYED
    flashHelper: '0x90FCe00Bed1547f8ED43441D1E5C9cAEE47f4811' as `0x${string}`, // ✅ DEPLOYED
    aavePool: '0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951' as `0x${string}`,
    uniswapRouter: '0xE592427A0AEce92De3Edee1F18E0157C05861564' as `0x${string}`,
  },
} as const;

export const SUPPORTED_ASSETS = {
  11155111: {
    WETH: {
      address: '0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c' as `0x${string}`,
      symbol: 'WETH',
      decimals: 18,
      icon: '⟠',
    },
    USDC: {
      address: '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8' as `0x${string}`,
      symbol: 'USDC',
      decimals: 6,
      icon: '💵',
    },
    DAI: {
      address: '0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357' as `0x${string}`,
      symbol: 'DAI',
      decimals: 18,
      icon: '◈',
    },
  },
} as const;

export const LOOPING_CONSTANTS = {
  MIN_HEALTH_FACTOR: 1.1,
  SAFE_HEALTH_FACTOR: 3.0,
  WARNING_HEALTH_FACTOR: 2.0,
  DANGER_HEALTH_FACTOR: 1.5,
  MAX_LTV: 8000, // 80%
  DEFAULT_LTV: 7000, // 70%
  DEFAULT_SLIPPAGE: 300, // 3%
  MAX_SLIPPAGE: 1000, // 10%
  MAX_LOOPS: 5,
};

export const HEALTH_FACTOR_ZONES = {
  SAFE: { min: 3.0, color: 'green', label: '🟢 Safe', description: 'Your position is healthy' },
  WARNING: { min: 1.5, max: 3.0, color: 'yellow', label: '🟡 Warning', description: 'Monitor your position' },
  DANGER: { min: 1.1, max: 1.5, color: 'red', label: '🔴 Danger', description: 'Risk of liquidation' },
  CRITICAL: { max: 1.1, color: 'red', label: '⚠️ Critical', description: 'Immediate action required' },
};

export function getHealthFactorZone(healthFactor: number) {
  if (healthFactor >= HEALTH_FACTOR_ZONES.SAFE.min) return HEALTH_FACTOR_ZONES.SAFE;
  if (healthFactor >= HEALTH_FACTOR_ZONES.WARNING.min) return HEALTH_FACTOR_ZONES.WARNING;
  if (healthFactor >= HEALTH_FACTOR_ZONES.DANGER.min) return HEALTH_FACTOR_ZONES.DANGER;
  return HEALTH_FACTOR_ZONES.CRITICAL;
}

export function formatHealthFactor(hf: bigint): string {
  const hfNumber = Number(hf) / 1e18;
  if (hfNumber > 10) return '>10.0';
  return hfNumber.toFixed(2);
}

export function formatLTV(ltv: bigint): string {
  const ltvNumber = Number(ltv) / 100;
  return ltvNumber.toFixed(2) + '%';
}

export function calculateLeverage(collateral: bigint, debt: bigint): number {
  if (collateral === BigInt(0)) return 1;
  const leverage = Number(collateral) / Number(collateral - debt);
  return Math.max(1, leverage);
}
