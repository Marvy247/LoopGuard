import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { LOOPING_CALLBACK_ABI, ERC20_ABI } from '../config/loopingABI';
import { parseUnits } from 'viem';

export function useLoopingCallback(callbackAddress?: string) {
  // Read position details
  const { data: positionDetails, refetch: refetchPosition, isLoading } = useReadContract({
    address: callbackAddress as `0x${string}`,
    abi: LOOPING_CALLBACK_ABI,
    functionName: 'getPositionDetails',
    query: {
      enabled: !!callbackAddress,
      refetchInterval: 10000, // Refetch every 10 seconds
    },
  });

  // Read contract state
  const { data: owner } = useReadContract({
    address: callbackAddress as `0x${string}`,
    abi: LOOPING_CALLBACK_ABI,
    functionName: 'owner',
    query: { enabled: !!callbackAddress },
  });

  const { data: collateralAsset } = useReadContract({
    address: callbackAddress as `0x${string}`,
    abi: LOOPING_CALLBACK_ABI,
    functionName: 'collateralAsset',
    query: { enabled: !!callbackAddress },
  });

  const { data: borrowAsset } = useReadContract({
    address: callbackAddress as `0x${string}`,
    abi: LOOPING_CALLBACK_ABI,
    functionName: 'borrowAsset',
    query: { enabled: !!callbackAddress },
  });

  const { data: targetLTV } = useReadContract({
    address: callbackAddress as `0x${string}`,
    abi: LOOPING_CALLBACK_ABI,
    functionName: 'targetLTV',
    query: { enabled: !!callbackAddress },
  });

  const { data: warningThreshold } = useReadContract({
    address: callbackAddress as `0x${string}`,
    abi: LOOPING_CALLBACK_ABI,
    functionName: 'warningThreshold',
    query: { enabled: !!callbackAddress },
  });

  const { data: dangerThreshold } = useReadContract({
    address: callbackAddress as `0x${string}`,
    abi: LOOPING_CALLBACK_ABI,
    functionName: 'dangerThreshold',
    query: { enabled: !!callbackAddress },
  });

  // Write: Execute leverage loop
  const {
    writeContract: executeLeverageLoop,
    data: executeTxHash,
    isPending: isExecuting,
    error: executeError,
  } = useWriteContract();

  const {
    isLoading: isExecuteConfirming,
    isSuccess: isExecuteConfirmed,
  } = useWaitForTransactionReceipt({
    hash: executeTxHash,
  });

  const handleExecuteLeverage = async (amount: string, decimals: number = 18) => {
    if (!callbackAddress) throw new Error('Callback address not set');

    return executeLeverageLoop({
      address: callbackAddress as `0x${string}`,
      abi: LOOPING_CALLBACK_ABI,
      functionName: 'executeLeverageLoop',
      args: [parseUnits(amount, decimals)],
    });
  };

  // Write: Unwind position
  const {
    writeContract: unwindPosition,
    data: unwindTxHash,
    isPending: isUnwinding,
    error: unwindError,
  } = useWriteContract();

  const {
    isLoading: isUnwindConfirming,
    isSuccess: isUnwindConfirmed,
  } = useWaitForTransactionReceipt({
    hash: unwindTxHash,
  });

  const handleUnwind = async () => {
    if (!callbackAddress) throw new Error('Callback address not set');

    return unwindPosition({
      address: callbackAddress as `0x${string}`,
      abi: LOOPING_CALLBACK_ABI,
      functionName: 'unwindPosition',
    });
  };

  // Token approval helper
  const {
    writeContract: approveToken,
    data: approveTxHash,
    isPending: isApproving,
  } = useWriteContract();

  const {
    isLoading: isApproveConfirming,
    isSuccess: isApproveConfirmed,
  } = useWaitForTransactionReceipt({
    hash: approveTxHash,
  });

  const handleApprove = async (tokenAddress: string, amount: string, decimals: number = 18) => {
    if (!callbackAddress) throw new Error('Callback address not set');

    return approveToken({
      address: tokenAddress as `0x${string}`,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [callbackAddress as `0x${string}`, parseUnits(amount, decimals)],
    });
  };

  return {
    // Read data
    positionDetails,
    owner,
    collateralAsset,
    borrowAsset,
    targetLTV,
    warningThreshold,
    dangerThreshold,
    isLoading,
    refetchPosition,
    
    // Execute leverage
    executeLeverage: handleExecuteLeverage,
    isExecuting,
    isExecuteConfirming,
    isExecuteConfirmed,
    executeError,
    
    // Unwind
    unwindPosition: handleUnwind,
    isUnwinding,
    isUnwindConfirming,
    isUnwindConfirmed,
    unwindError,
    
    // Token approval
    approveToken: handleApprove,
    isApproving,
    isApproveConfirming,
    isApproveConfirmed,
  };
}
