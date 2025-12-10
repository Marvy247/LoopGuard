'use client';

import { useState, useEffect } from 'react';
import { usePublicClient } from 'wagmi';
import { LOOPING_ADDRESSES } from '@/config/looping';
import { LOOPING_FACTORY_ABI } from '@/config/loopingABI';

export function PositionsList({ userAddress }: { userAddress: string }) {
  const [positions, setPositions] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [wrongNetwork, setWrongNetwork] = useState(false);
  const publicClient = usePublicClient();

  useEffect(() => {
    const fetchPositions = async () => {
      if (!publicClient) return;
      
      try {
        setLoading(true);
        console.log('=== Fetching positions for:', userAddress);
        console.log('=== Factory address:', LOOPING_ADDRESSES[11155111].factory);
        
        // Skip getUserPositions, go straight to events (more reliable)
        console.log('=== Fetching PositionCreated events from blockchain...');
        
        // Get current block and verify network
        const currentBlock = await publicClient.getBlockNumber();
        const chainId = await publicClient.getChainId();
        console.log('=== Current block number:', currentBlock);
        console.log('=== Connected to chainId:', chainId);
        console.log('=== Expected chainId: 11155111 (Ethereum Sepolia)');
        
        // Check if wrong network
        if (chainId !== 11155111) {
          console.error('=== ❌ WRONG NETWORK! Connected to chainId', chainId, 'but contracts are on Ethereum Sepolia (11155111)');
          setWrongNetwork(true);
          setLoading(false);
          return;
        }
        
        console.log('=== ✅ Correct network (Ethereum Sepolia)');
        
        // Search in smaller chunks (last 1000 blocks only - much faster)
        const fromBlock = currentBlock > BigInt(1000) ? currentBlock - BigInt(1000) : BigInt(0);
        console.log('=== Searching from block:', fromBlock, 'to', currentBlock);
        console.log('=== (Searching last 1000 blocks for performance)');
        
        console.log('=== Fetching all logs from factory...');
        
        let logs: any[];
        try {
          // Try with timeout
          const logsPromise = publicClient.getLogs({
            address: LOOPING_ADDRESSES[11155111].factory as `0x${string}`,
            fromBlock: fromBlock,
            toBlock: currentBlock,
          });
          
          // Add 10 second timeout
          const timeoutPromise = new Promise<never>((_, reject) => 
            setTimeout(() => reject(new Error('Timeout after 10s')), 10000)
          );
          
          logs = (await Promise.race([logsPromise, timeoutPromise])) as any[];
          console.log('=== getLogs completed successfully');
        } catch (error: any) {
          console.error('=== Error fetching logs:', error.message);
          throw error;
        }
        
        console.log('=== Total PositionCreated events found:', logs.length);
        console.log('=== All events:', logs);
        
        // Filter events for this user
        const userLogs = logs.filter((log: any) => {
          const topics = log.topics as string[];
          const ownerTopic = topics[1];
          // Remove 0x and pad to compare addresses
          const owner = '0x' + ownerTopic.slice(-40);
          const matches = owner.toLowerCase() === userAddress.toLowerCase();
          console.log(`=== Event owner: ${owner}, User: ${userAddress}, Matches: ${matches}`);
          return matches;
        });
        
        console.log('=== Events for this user:', userLogs.length);
        console.log('=== User event details:', userLogs);
        
        if (userLogs.length > 0) {
          const eventPositions = userLogs.map((log: any) => {
            const topics = log.topics as string[];
            const callbackTopic = topics[2]; // Second indexed param
            const callbackAddress = '0x' + callbackTopic.slice(-40);
            console.log('=== Position callback address:', callbackAddress);
            return callbackAddress;
          });
          console.log('=== Final position addresses:', eventPositions);
          setPositions(eventPositions);
        } else {
          console.log('=== No positions found for this user in events');
          setPositions([]);
        }
        
      } catch (error) {
        console.error('Error fetching positions:', error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchPositions();
  }, [userAddress, publicClient]);

  if (wrongNetwork) {
    return (
      <div className="text-center py-8 border border-red-500/30 rounded-xl bg-red-900/10 p-6">
        <div className="text-6xl mb-4">⚠️</div>
        <p className="text-white font-bold text-xl mb-2">Wrong Network!</p>
        <p className="text-gray-400 mb-4">
          You're connected to the wrong network.
        </p>
        <div className="bg-black/30 p-4 rounded-lg mb-4">
          <p className="text-sm text-gray-400 mb-2">Contracts are deployed on:</p>
          <p className="text-white font-bold">Ethereum Sepolia</p>
          <p className="text-xs text-gray-500 mt-1">ChainId: 11155111</p>
        </div>
        <p className="text-sm text-gray-400 mb-4">
          Please switch to <strong className="text-white">Ethereum Sepolia</strong> in your wallet
        </p>
        <button
          onClick={() => window.location.reload()}
          className="bg-white text-black px-6 py-3 rounded-full font-bold hover:bg-gray-200 transition"
        >
          Reload After Switching Network
        </button>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="text-center py-8 border border-white/10 rounded-xl bg-white/[0.02] p-6">
        <div className="text-4xl mb-4">🔍</div>
        <p className="text-gray-400">Scanning blockchain for PositionCreated events...</p>
        <p className="text-xs text-gray-600 mt-2">Check console (F12) for details</p>
      </div>
    );
  }

  if (positions.length === 0) {
    return (
      <div className="text-center py-8 border border-white/10 rounded-xl bg-white/[0.02] p-6">
        <div className="text-4xl mb-4">❌</div>
        <p className="text-white font-bold mb-2">No positions found in recent blocks</p>
        <p className="text-gray-400 text-sm mb-4">
          Searched last 1000 blocks - no PositionCreated events found
        </p>
        <div className="text-left max-w-md mx-auto mt-4 p-3 border border-white/5 rounded-lg bg-black/30">
          <p className="text-xs text-gray-500 mb-2">Searched:</p>
          <p className="text-xs text-gray-600 font-mono">Factory: {LOOPING_ADDRESSES[11155111]?.factory?.slice(0, 20)}...</p>
          <p className="text-xs text-gray-600 font-mono">User: {userAddress.slice(0, 20)}...</p>
          <p className="text-xs text-gray-600 font-mono">Range: Last 1000 blocks</p>
        </div>
        <div className="mt-6 p-4 border border-white/20 rounded-lg bg-white/[0.02]">
          <p className="text-white font-bold mb-2 text-sm">🔍 Debug Your Position Creation:</p>
          <ol className="text-left text-xs text-gray-400 space-y-2">
            <li>1. Check if your transaction succeeded on Etherscan</li>
            <li>2. Look for "PositionCreated" event in transaction logs</li>
            <li>3. Verify you're on Sepolia network</li>
            <li>4. Make sure you used the correct factory address</li>
          </ol>
          <a 
            href={`https://sepolia.etherscan.io/address/${userAddress}#internaltx`}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-4 inline-block bg-white text-black px-4 py-2 rounded-full text-xs font-bold hover:bg-gray-200 transition"
          >
            View My Transactions on Etherscan →
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="border border-white/20 rounded-xl bg-white/[0.05] p-6">
        <div className="text-4xl mb-4">✅</div>
        <p className="text-white font-bold text-xl mb-2">
          Found {positions.length} position(s) from blockchain events!
        </p>
        <p className="text-gray-400 text-sm">
          These are your callback contract addresses:
        </p>
      </div>
      {positions.map((pos, idx) => (
        <div key={pos} className="border border-white/20 p-6 rounded-xl bg-white/[0.03] hover:bg-white/[0.05] transition">
          <div className="flex justify-between items-start mb-2">
            <span className="text-gray-400 text-sm">Position #{idx + 1}</span>
            <span className="text-white text-xs px-2 py-1 bg-white/10 rounded-full">Active</span>
          </div>
          <p className="text-white font-mono text-sm break-all">{pos}</p>
          <div className="mt-4 flex gap-2">
            <button className="flex-1 bg-white text-black px-4 py-2 rounded-full font-bold text-sm hover:bg-gray-200 transition">
              View Position
            </button>
            <button className="border border-white/20 text-white px-4 py-2 rounded-full font-bold text-sm hover:bg-white/5 transition">
              Execute
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
