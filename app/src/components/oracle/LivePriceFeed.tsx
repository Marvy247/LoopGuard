'use client';

import { useEffect, useState } from 'react';
import { useReadContract } from 'wagmi';
import { formatUnits } from 'viem';
import { Activity, Clock, TrendingUp, TrendingDown, AlertCircle } from 'lucide-react';
import { CONTRACTS, FEED_PROXY_ABI, CHAIN_IDS } from '@/config/contracts';

export default function LivePriceFeed() {
  const [priceHistory, setPriceHistory] = useState<number[]>([]);
  
  // Read latest price from FeedProxy
  const { data: priceData, isLoading, isError, refetch } = useReadContract({
    address: CONTRACTS.feedProxy,
    abi: FEED_PROXY_ABI,
    functionName: 'latestRoundData',
    chainId: CHAIN_IDS.destination,
  });

  const [roundId, answer, startedAt, updatedAt, answeredInRound] = priceData || [];
  const price = answer ? Number(formatUnits(answer as bigint, 8)) : null;
  const lastUpdate = updatedAt ? new Date(Number(updatedAt) * 1000) : null;
  const timeSinceUpdate = lastUpdate ? Math.floor((Date.now() - lastUpdate.getTime()) / 1000) : null;

  // Track price changes
  useEffect(() => {
    if (price) {
      setPriceHistory((prev) => [...prev.slice(-9), price]);
    }
  }, [price]);

  const priceChange = priceHistory.length >= 2 
    ? ((priceHistory[priceHistory.length - 1] - priceHistory[priceHistory.length - 2]) / priceHistory[priceHistory.length - 2]) * 100
    : 0;

  const isStale = timeSinceUpdate ? timeSinceUpdate > 3600 : false; // >1 hour

  return (
    <section id="live-feed" className="py-20 px-6 relative">
      <div className="max-w-7xl mx-auto">
        {/* Section Header */}
        <div className="text-center mb-12">
          <h2 className="text-4xl md:text-5xl font-bold text-white mb-4">
            Live Price Feed
          </h2>
          <p className="text-lg text-slate-400">
            Real-time ETH/USD price mirrored from Ethereum Sepolia to Base Sepolia
          </p>
        </div>

        {/* Main Price Card */}
        <div className="max-w-4xl mx-auto">
          <div className="relative bg-gradient-to-br from-slate-800/50 to-slate-900/50 backdrop-blur-xl border border-white/10 rounded-2xl p-8 shadow-2xl">
            {/* Status Indicator */}
            <div className="absolute top-6 right-6">
              {isLoading ? (
                <div className="flex items-center gap-2 px-3 py-1.5 bg-yellow-500/10 border border-yellow-500/20 rounded-full">
                  <div className="w-2 h-2 bg-yellow-400 rounded-full animate-pulse" />
                  <span className="text-xs text-yellow-400">Loading...</span>
                </div>
              ) : isError || !price ? (
                <div className="flex items-center gap-2 px-3 py-1.5 bg-red-500/10 border border-red-500/20 rounded-full">
                  <AlertCircle className="w-3 h-3 text-red-400" />
                  <span className="text-xs text-red-400">Not Deployed</span>
                </div>
              ) : isStale ? (
                <div className="flex items-center gap-2 px-3 py-1.5 bg-orange-500/10 border border-orange-500/20 rounded-full">
                  <AlertCircle className="w-3 h-3 text-orange-400" />
                  <span className="text-xs text-orange-400">Stale Data</span>
                </div>
              ) : (
                <div className="flex items-center gap-2 px-3 py-1.5 bg-green-500/10 border border-green-500/20 rounded-full">
                  <Activity className="w-3 h-3 text-green-400 animate-pulse" />
                  <span className="text-xs text-green-400">Live</span>
                </div>
              )}
            </div>

            {/* Price Display */}
            <div className="mb-8">
              <div className="text-sm text-slate-400 mb-2">ETH / USD</div>
              {isLoading ? (
                <div className="h-20 bg-slate-700/30 rounded-lg animate-pulse" />
              ) : price ? (
                <>
                  <div className="flex items-baseline gap-4">
                    <div className="text-6xl font-bold text-white">
                      ${price.toFixed(2)}
                    </div>
                    {priceChange !== 0 && (
                      <div className={`flex items-center gap-1 px-3 py-1 rounded-lg ${
                        priceChange > 0 
                          ? 'bg-green-500/10 text-green-400' 
                          : 'bg-red-500/10 text-red-400'
                      }`}>
                        {priceChange > 0 ? (
                          <TrendingUp className="w-4 h-4" />
                        ) : (
                          <TrendingDown className="w-4 h-4" />
                        )}
                        <span className="text-sm font-semibold">
                          {Math.abs(priceChange).toFixed(2)}%
                        </span>
                      </div>
                    )}
                  </div>
                  <div className="text-sm text-slate-500 mt-1">
                    8 decimals precision
                  </div>
                </>
              ) : (
                <div className="text-4xl text-slate-600">
                  Waiting for deployment...
                </div>
              )}
            </div>

            {/* Metadata Grid */}
            {price && (
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 pt-6 border-t border-white/10">
                <div>
                  <div className="text-xs text-slate-400 mb-1">Round ID</div>
                  <div className="text-sm font-mono text-white">
                    #{roundId?.toString().slice(-6)}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-slate-400 mb-1">Last Update</div>
                  <div className="flex items-center gap-1 text-sm text-white">
                    <Clock className="w-3 h-3" />
                    {timeSinceUpdate !== null ? (
                      timeSinceUpdate < 60 
                        ? `${timeSinceUpdate}s ago`
                        : `${Math.floor(timeSinceUpdate / 60)}m ago`
                    ) : 'N/A'}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-slate-400 mb-1">Timestamp</div>
                  <div className="text-sm text-white">
                    {lastUpdate?.toLocaleTimeString()}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-slate-400 mb-1">Status</div>
                  <div className="text-sm text-green-400 font-semibold">
                    {isStale ? 'Stale' : 'Fresh'}
                  </div>
                </div>
              </div>
            )}

            {/* Mini Chart (Price History) */}
            {priceHistory.length > 1 && (
              <div className="mt-6 pt-6 border-t border-white/10">
                <div className="text-xs text-slate-400 mb-3">Price Trend (Last 10 Updates)</div>
                <div className="flex items-end gap-1 h-16">
                  {priceHistory.map((p, i) => {
                    const maxPrice = Math.max(...priceHistory);
                    const minPrice = Math.min(...priceHistory);
                    const range = maxPrice - minPrice || 1;
                    const height = ((p - minPrice) / range) * 100;
                    const isLatest = i === priceHistory.length - 1;
                    
                    return (
                      <div
                        key={i}
                        className={`flex-1 rounded-t transition-all ${
                          isLatest ? 'bg-green-400' : 'bg-slate-600'
                        }`}
                        style={{ height: `${Math.max(height, 10)}%` }}
                      />
                    );
                  })}
                </div>
              </div>
            )}

            {/* Refresh Button */}
            <button
              onClick={() => refetch()}
              className="mt-6 w-full py-3 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg text-white font-medium transition-all"
            >
              Refresh Data
            </button>
          </div>
        </div>

        {/* Info Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12 max-w-4xl mx-auto">
          <div className="p-6 bg-white/5 border border-white/10 rounded-xl">
            <div className="text-2xl font-bold text-white mb-1">~5min</div>
            <div className="text-sm text-slate-400">Update Frequency</div>
            <div className="text-xs text-slate-500 mt-2">
              Cron fallback ensures updates even if events are missed
            </div>
          </div>

          <div className="p-6 bg-white/5 border border-white/10 rounded-xl">
            <div className="text-2xl font-bold text-white mb-1">0.5%</div>
            <div className="text-sm text-slate-400">Deviation Threshold</div>
            <div className="text-xs text-slate-500 mt-2">
              Updates triggered only on significant price changes
            </div>
          </div>

          <div className="p-6 bg-white/5 border border-white/10 rounded-xl">
            <div className="text-2xl font-bold text-white mb-1">20%</div>
            <div className="text-sm text-slate-400">Circuit Breaker</div>
            <div className="text-xs text-slate-500 mt-2">
              Automatic halt on suspicious price jumps
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
