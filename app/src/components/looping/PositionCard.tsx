'use client';

import { useState } from 'react';
import { useLoopingCallback } from '@/hooks/useLoopingCallback';
import { formatHealthFactor, formatLTV, calculateLeverage, getHealthFactorZone } from '@/config/looping';

interface PositionCardProps {
  address: string;
  onExecute: () => void;
  onUnwind: () => void;
}

export function PositionCard({ address, onExecute, onUnwind }: PositionCardProps) {
  const [showDetails, setShowDetails] = useState(false);
  const {
    positionDetails,
    collateralAsset,
    borrowAsset,
    targetLTV,
    warningThreshold,
    dangerThreshold,
    isLoading,
    refetchPosition,
  } = useLoopingCallback(address);

  if (isLoading) {
    return (
      <div className="border border-white/10 p-6 rounded-2xl bg-white/[0.02] animate-pulse">
        <div className="h-6 bg-white/5 rounded w-3/4 mb-4"></div>
        <div className="h-4 bg-white/5 rounded w-1/2"></div>
      </div>
    );
  }

  if (!positionDetails) {
    return null;
  }

  const [totalCollateral, totalDebt, availableBorrow, currentLTV, healthFactor, loops] = positionDetails;
  
  const hfNumber = Number(healthFactor) / 1e18;
  const zone = getHealthFactorZone(hfNumber);
  const leverage = calculateLeverage(totalCollateral, totalDebt);
  const hasDebt = totalDebt > BigInt(0);

  return (
    <div className={`border p-6 rounded-2xl transition-all bg-white/[0.02] hover:bg-white/[0.03] ${
      zone.color === 'green' ? 'border-white/20' :
      zone.color === 'yellow' ? 'border-white/30' :
      'border-white/40'
    }`}>
      {/* Header */}
      <div className="flex justify-between items-start mb-4">
        <div>
          <h3 className="font-bold text-lg mb-1">Position #{address.slice(-6)}</h3>
          <p className="text-sm text-gray-400 font-mono">{address.slice(0, 10)}...{address.slice(-8)}</p>
        </div>
        <div className="text-right">
          <span className={`inline-block px-3 py-1 rounded-full text-sm font-bold ${
            zone.color === 'green' ? 'bg-white/10 text-white' :
            zone.color === 'yellow' ? 'bg-white/20 text-white' :
            'bg-white/30 text-white'
          }`}>
            {zone.label}
          </span>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-2 gap-4 mb-4">
        <div className="border border-white/10 p-3 rounded-xl bg-white/[0.01]">
          <p className="text-xs text-gray-400 mb-1">Health Factor</p>
          <p className="text-2xl font-bold text-white">
            {formatHealthFactor(healthFactor)}
          </p>
        </div>
        <div className="border border-white/10 p-3 rounded-xl bg-white/[0.01]">
          <p className="text-xs text-gray-400 mb-1">Leverage</p>
          <p className="text-2xl font-bold text-white">{leverage.toFixed(2)}x</p>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="mb-4">
        <div className="flex justify-between text-xs mb-1">
          <span className="text-gray-400">LTV</span>
          <span className="font-bold">{formatLTV(currentLTV)}</span>
        </div>
        <div className="w-full bg-white/10 rounded-full h-2">
          <div 
            className={`h-2 rounded-full transition-all ${
              Number(currentLTV) < 6000 ? 'bg-white' :
              Number(currentLTV) < 7500 ? 'bg-gray-300' :
              'bg-gray-500'
            }`}
            style={{ width: `${Math.min(Number(currentLTV) / 100, 100)}%` }}
          ></div>
        </div>
      </div>

      {/* Collateral & Debt */}
      {showDetails && (
        <div className="mb-4 space-y-2 text-sm">
          <div className="flex justify-between">
            <span className="text-gray-400">Total Collateral:</span>
            <span className="font-mono">{(Number(totalCollateral) / 1e18).toFixed(4)} ETH</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-400">Total Debt:</span>
            <span className="font-mono">{(Number(totalDebt) / 1e18).toFixed(4)} ETH</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-400">Available to Borrow:</span>
            <span className="font-mono">{(Number(availableBorrow) / 1e18).toFixed(4)} ETH</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-400">Loop Count:</span>
            <span className="font-bold">{Number(loops)}</span>
          </div>
          <div className="border-t border-white/10 pt-2 mt-2">
            <div className="flex justify-between">
              <span className="text-gray-400">Warning HF:</span>
              <span className="text-gray-300">{formatHealthFactor(warningThreshold || BigInt(0))}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Danger HF:</span>
              <span className="text-white">{formatHealthFactor(dangerThreshold || BigInt(0))}</span>
            </div>
          </div>
        </div>
      )}

      {/* Actions */}
      <div className="flex gap-2 mb-3">
        {!hasDebt && (
          <button
            onClick={onExecute}
            className="flex-1 bg-white text-black hover:bg-gray-200 font-bold py-2 px-4 rounded-full transition"
          >
            Execute Leverage
          </button>
        )}
        {hasDebt && (
          <button
            onClick={onUnwind}
            className="flex-1 border border-white/20 text-white hover:bg-white/5 font-bold py-2 px-4 rounded-full transition"
          >
            Unwind Position
          </button>
        )}
        <button
          onClick={() => refetchPosition()}
          className="border border-white/10 hover:bg-white/5 text-white font-bold py-2 px-4 rounded-full transition"
          title="Refresh"
        >
          ↻
        </button>
      </div>

      {/* Toggle Details */}
      <button
        onClick={() => setShowDetails(!showDetails)}
        className="w-full text-sm text-gray-400 hover:text-white transition"
      >
        {showDetails ? '▲ Hide Details' : '▼ Show Details'}
      </button>

      {/* Protection Status */}
      <div className="mt-4 pt-4 border-t border-white/10">
        <div className="flex items-center gap-2 text-sm">
          <span className="text-white">🛡️</span>
          <span className="text-gray-400">Reactive Protection: </span>
          <span className="text-white font-bold">Active</span>
        </div>
        <p className="text-xs text-gray-500 mt-1">
          24/7 monitoring • {zone.description}
        </p>
      </div>
    </div>
  );
}
