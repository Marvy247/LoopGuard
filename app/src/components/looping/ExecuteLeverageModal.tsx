'use client';

import { useState } from 'react';
import { useLoopingCallback } from '@/hooks/useLoopingCallback';

interface ExecuteLeverageModalProps {
  callbackAddress: string;
  collateralAsset: string;
  onClose: () => void;
  onSuccess: () => void;
}

export function ExecuteLeverageModal({ 
  callbackAddress, 
  collateralAsset, 
  onClose, 
  onSuccess 
}: ExecuteLeverageModalProps) {
  const [amount, setAmount] = useState('');
  const [step, setStep] = useState<'approve' | 'execute'>('approve');
  
  const {
    approveToken,
    isApproving,
    isApproveConfirming,
    isApproveConfirmed,
    executeLeverage,
    isExecuting,
    isExecuteConfirming,
    isExecuteConfirmed,
  } = useLoopingCallback(callbackAddress);

  const handleApprove = async () => {
    try {
      await approveToken(collateralAsset, amount);
      // Move to execute step after confirmation
      setTimeout(() => setStep('execute'), 2000);
    } catch (error) {
      console.error('Approval failed:', error);
    }
  };

  const handleExecute = async () => {
    try {
      await executeLeverage(amount);
      // Wait for confirmation then call success
      setTimeout(() => {
        onSuccess();
        onClose();
      }, 3000);
    } catch (error) {
      console.error('Execution failed:', error);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
      <div className="bg-gradient-to-br from-gray-900 to-black border border-purple-500/30 rounded-2xl p-8 max-w-md w-full">
        <div className="flex justify-between items-start mb-6">
          <div>
            <h2 className="text-2xl font-bold mb-2">⚡ Execute Leverage Loop</h2>
            <p className="text-sm text-gray-400">Supply collateral to create leveraged position</p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white text-2xl"
          >
            ×
          </button>
        </div>

        {/* Amount Input */}
        <div className="mb-6">
          <label className="block text-sm font-bold mb-2">
            Amount ({collateralAsset === '0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c' ? 'WETH' : 'Token'})
          </label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.0"
            className="w-full bg-black/50 border border-gray-600 rounded-lg px-4 py-3 text-white text-lg"
            disabled={step === 'execute'}
          />
          <p className="text-xs text-gray-400 mt-2">
            This amount will be used as initial collateral for the leverage loop
          </p>
        </div>

        {/* Steps */}
        <div className="mb-6 space-y-3">
          {/* Step 1: Approve */}
          <div className={`p-4 rounded-lg border ${
            step === 'approve' ? 'border-purple-500 bg-purple-900/20' : 'border-gray-700 bg-black/30'
          }`}>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold ${
                  isApproveConfirmed ? 'bg-green-500 text-white' :
                  step === 'approve' ? 'bg-purple-600 text-white' :
                  'bg-gray-700 text-gray-400'
                }`}>
                  {isApproveConfirmed ? '✓' : '1'}
                </div>
                <div>
                  <p className="font-bold">Approve Token</p>
                  <p className="text-xs text-gray-400">Allow contract to use your tokens</p>
                </div>
              </div>
              {step === 'approve' && !isApproveConfirmed && (
                <button
                  onClick={handleApprove}
                  disabled={!amount || isApproving || isApproveConfirming}
                  className="bg-purple-600 hover:bg-purple-700 disabled:bg-gray-600 disabled:cursor-not-allowed px-4 py-2 rounded-lg font-bold text-sm transition"
                >
                  {isApproving || isApproveConfirming ? 'Approving...' : 'Approve'}
                </button>
              )}
            </div>
          </div>

          {/* Step 2: Execute */}
          <div className={`p-4 rounded-lg border ${
            step === 'execute' ? 'border-purple-500 bg-purple-900/20' : 'border-gray-700 bg-black/30'
          }`}>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold ${
                  isExecuteConfirmed ? 'bg-green-500 text-white' :
                  step === 'execute' ? 'bg-purple-600 text-white' :
                  'bg-gray-700 text-gray-400'
                }`}>
                  {isExecuteConfirmed ? '✓' : '2'}
                </div>
                <div>
                  <p className="font-bold">Execute Loop</p>
                  <p className="text-xs text-gray-400">Start the leverage process</p>
                </div>
              </div>
              {step === 'execute' && !isExecuteConfirmed && (
                <button
                  onClick={handleExecute}
                  disabled={isExecuting || isExecuteConfirming}
                  className="bg-purple-600 hover:bg-purple-700 disabled:bg-gray-600 disabled:cursor-not-allowed px-4 py-2 rounded-lg font-bold text-sm transition"
                >
                  {isExecuting || isExecuteConfirming ? 'Executing...' : 'Execute'}
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Info Box */}
        <div className="bg-blue-900/30 border border-blue-500/30 rounded-lg p-4 mb-4">
          <h4 className="font-bold mb-2 flex items-center gap-2">
            <span>ℹ️</span> What Happens Next?
          </h4>
          <ul className="text-sm text-gray-300 space-y-1">
            <li>• Your collateral will be supplied to Aave</li>
            <li>• Contract will borrow against it and swap</li>
            <li>• Process repeats up to 5 times for target leverage</li>
            <li>• Reactive guardian starts 24/7 monitoring</li>
          </ul>
        </div>

        {/* Success Message */}
        {isExecuteConfirmed && (
          <div className="bg-green-900/30 border border-green-500/30 rounded-lg p-4">
            <p className="text-green-400 font-bold">✅ Position Created Successfully!</p>
            <p className="text-sm text-gray-400 mt-1">
              Your leveraged position is now active and protected by Reactive Network
            </p>
          </div>
        )}

        {/* Cancel Button */}
        {!isExecuteConfirmed && (
          <button
            onClick={onClose}
            className="w-full mt-4 bg-gray-700 hover:bg-gray-600 text-white font-bold py-3 rounded-lg transition"
          >
            Cancel
          </button>
        )}
      </div>
    </div>
  );
}
