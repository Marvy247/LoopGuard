'use client';

import Link from 'next/link';

export default function Home() {
  return (
    <div className="min-h-screen bg-black text-white">
      <div className="container mx-auto px-4 py-16">
        {/* Header */}
        <div className="text-center mb-20">
          <div className="inline-block mb-6 px-4 py-2 border border-white/20 rounded-full">
            <p className="text-sm text-gray-400">Reactive Network Bounty #2</p>
          </div>
          <h1 className="text-7xl md:text-8xl font-bold mb-6 tracking-tight">
            <span className="text-white">Loop</span>
            <span className="text-gray-500">Guard</span>
          </h1>
          <p className="text-2xl md:text-3xl text-gray-400 mb-4 font-light">
            Your Position&apos;s 24/7 Guardian
          </p>
          <p className="text-lg text-gray-500 max-w-2xl mx-auto mb-8">
            Leveraged looping with autonomous liquidation defense. While you sleep, we watch.
          </p>
          <div className="flex flex-col items-center gap-4">
            <Link 
              href="/dashboard" 
              className="inline-block bg-white text-black px-8 py-4 rounded-full font-bold text-lg hover:bg-gray-200 transition"
            >
              Launch Dashboard →
            </Link>
            <w3m-button />
          </div>
        </div>

        {/* Hero Section */}
        <div className="border border-white/10 rounded-3xl p-12 mb-16 bg-white/[0.02] backdrop-blur-sm">
          <div className="text-center">
            <h2 className="text-4xl font-bold mb-6 text-white">Autonomous Protection</h2>
            <p className="text-xl text-gray-400 mb-12 max-w-3xl mx-auto">
              The first self-defending leveraged position protocol. Three tiers of automatic protection keep your capital safe.
            </p>
            <div className="grid md:grid-cols-3 gap-6 mt-8">
              <div className="border border-white/10 p-8 rounded-2xl bg-white/[0.01] hover:bg-white/[0.03] transition-all">
                <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center mb-4 mx-auto">
                  <span className="text-black text-2xl">✓</span>
                </div>
                <h3 className="text-xl font-bold mb-3 text-white">Safe Zone</h3>
                <p className="text-gray-400 text-sm">Health Factor &gt; 3.0</p>
                <p className="text-gray-500 text-sm mt-2">Monitor only, position healthy</p>
              </div>
              <div className="border border-white/10 p-8 rounded-2xl bg-white/[0.01] hover:bg-white/[0.03] transition-all">
                <div className="w-12 h-12 bg-gray-300 rounded-full flex items-center justify-center mb-4 mx-auto">
                  <span className="text-black text-2xl">!</span>
                </div>
                <h3 className="text-xl font-bold mb-3 text-white">Warning</h3>
                <p className="text-gray-400 text-sm">Health Factor 1.5-2.0</p>
                <p className="text-gray-500 text-sm mt-2">Auto-reduce leverage 20%</p>
              </div>
              <div className="border border-white/10 p-8 rounded-2xl bg-white/[0.01] hover:bg-white/[0.03] transition-all">
                <div className="w-12 h-12 bg-gray-600 rounded-full flex items-center justify-center mb-4 mx-auto">
                  <span className="text-white text-2xl">⚠</span>
                </div>
                <h3 className="text-xl font-bold mb-3 text-white">Danger</h3>
                <p className="text-gray-400 text-sm">Health Factor &lt; 1.5</p>
                <p className="text-gray-500 text-sm mt-2">Emergency deleverage 60%</p>
              </div>
            </div>
          </div>
        </div>

        {/* Key Features */}
        <div className="grid md:grid-cols-2 gap-6 mb-16">
          <div className="border border-white/10 p-8 rounded-2xl bg-white/[0.02]">
            <h3 className="text-2xl font-bold mb-6 text-white">Smart Contracts</h3>
            <ul className="space-y-4 text-gray-400">
              <li className="flex items-start">
                <span className="mr-3 text-white">→</span>
                <div>
                  <strong className="text-white">LoopingReactive.sol</strong>
                  <p className="text-sm text-gray-500">24/7 Guardian on Reactive Network</p>
                </div>
              </li>
              <li className="flex items-start">
                <span className="mr-3 text-white">→</span>
                <div>
                  <strong className="text-white">LoopingCallback.sol</strong>
                  <p className="text-sm text-gray-500">Executor on origin chain</p>
                </div>
              </li>
              <li className="flex items-start">
                <span className="mr-3 text-white">→</span>
                <div>
                  <strong className="text-white">FlashLoanHelper.sol</strong>
                  <p className="text-sm text-gray-500">One-transaction leverage</p>
                </div>
              </li>
              <li className="flex items-start">
                <span className="mr-3 text-white">→</span>
                <div>
                  <strong className="text-white">LoopingFactory.sol</strong>
                  <p className="text-sm text-gray-500">Position deployer</p>
                </div>
              </li>
            </ul>
          </div>

          <div className="border border-white/10 p-8 rounded-2xl bg-white/[0.02]">
            <h3 className="text-2xl font-bold mb-6 text-white">Key Innovations</h3>
            <ul className="space-y-4 text-gray-400">
              <li className="flex items-start">
                <span className="mr-3 text-white">•</span>
                <span>Autonomous 24/7 health monitoring</span>
              </li>
              <li className="flex items-start">
                <span className="mr-3 text-white">•</span>
                <span>Three-tier automatic protection</span>
              </li>
              <li className="flex items-start">
                <span className="mr-3 text-white">•</span>
                <span>Flash loan optimization (80% gas saved)</span>
              </li>
              <li className="flex items-start">
                <span className="mr-3 text-white">•</span>
                <span>Zero user interaction required</span>
              </li>
            </ul>
          </div>
        </div>

        {/* Architecture */}
        <div className="border border-white/10 p-8 rounded-2xl mb-16 bg-white/[0.01]">
          <h3 className="text-2xl font-bold mb-6 text-center text-white">Architecture</h3>
          <div className="bg-black border border-white/5 p-6 rounded-xl font-mono text-sm overflow-x-auto">
            <pre className="text-gray-400">{`
┌─────────────────┐
│ Looping Factory │
│  Deploy System  │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌──────────────────┐    ┌──────────────────────┐
│ LoopingCallback  │◄───│ LoopingReactive      │
│ (Origin Chain)   │    │ (Reactive Network)   │
│                  │    │                      │
│ • Execute loops  │    │ 🛡️ THE GUARDIAN      │
│ • Manage position│    │ • Monitor 24/7       │
│ • Auto-protect   │    │ • Trigger protection │
└────────┬─────────┘    └──────────────────────┘
         │
         ▼
┌────────────────────────┐
│    AAVE V3 PROTOCOL    │
│ Supply → Borrow → Swap │
└────────────────────────┘
            `}</pre>
          </div>
        </div>

        {/* Technical Details */}
        <div className="grid md:grid-cols-3 gap-6 mb-16">
          <div className="border border-white/10 p-6 rounded-2xl bg-white/[0.01] hover:bg-white/[0.02] transition-all">
            <h4 className="text-lg font-bold mb-3 text-white">Testing</h4>
            <p className="text-2xl font-bold text-white">11/11</p>
            <p className="text-sm text-gray-500 mt-2">All tests passing</p>
          </div>
          <div className="border border-white/10 p-6 rounded-2xl bg-white/[0.01] hover:bg-white/[0.02] transition-all">
            <h4 className="text-lg font-bold mb-3 text-white">Protocols</h4>
            <p className="text-gray-400">Aave V3</p>
            <p className="text-gray-400">Uniswap V3</p>
          </div>
          <div className="border border-white/10 p-6 rounded-2xl bg-white/[0.01] hover:bg-white/[0.02] transition-all">
            <h4 className="text-lg font-bold mb-3 text-white">Performance</h4>
            <p className="text-2xl font-bold text-white">80%</p>
            <p className="text-sm text-gray-500 mt-2">Gas savings</p>
          </div>
        </div>



        {/* Documentation */}
        <div className="border border-white/10 p-12 rounded-3xl mb-16 bg-white/[0.01]">
          <h3 className="text-3xl font-bold mb-4 text-center text-white">Documentation</h3>
          <p className="text-center text-gray-400 mb-8 max-w-2xl mx-auto">
            Smart contracts live in <code className="bg-white/5 px-3 py-1 rounded border border-white/10">/Contracts/src/looping/</code>
          </p>
          <div className="flex flex-wrap justify-center gap-4">
            <a 
              href="https://github.com" 
              className="bg-white text-black px-6 py-3 rounded-full font-bold hover:bg-gray-200 transition"
              target="_blank"
              rel="noopener noreferrer"
            >
              View on GitHub
            </a>
            <button 
              className="border border-white/20 text-white px-6 py-3 rounded-full font-bold hover:bg-white/5 transition"
            >
              Technical Docs
            </button>
          </div>
        </div>

        {/* Footer */}
        <div className="text-center mt-20 pt-12 border-t border-white/10">
          <p className="text-gray-500 mb-2">Built for Reactive Network Bounty #2</p>
          <p className="text-sm text-gray-600">Deadline: December 14, 2024, 11:59 PM UTC</p>
          <p className="text-sm text-gray-600 mt-4">🛡️ LoopGuard — Your Position&apos;s 24/7 Guardian</p>
        </div>
      </div>
    </div>
  );
}
