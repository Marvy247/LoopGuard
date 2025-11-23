import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Toaster } from 'react-hot-toast';
import { Web3Provider } from "@/providers/Web3Provider";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Reactive Cross-Chain Oracle | Bounty #1 Submission",
  description:
    "Autonomous cross-chain price feed oracle powered by Reactive Contracts. Mirror Chainlink feeds from Ethereum to Base with zero trust assumptions.",
  keywords:
    "reactive contracts, cross-chain oracle, chainlink, price feed, defi, ethereum, base, trustless oracle",
  openGraph: {
    title: "Reactive Cross-Chain Oracle",
    description:
      "Production-grade cross-chain oracle using Reactive Contracts for autonomous price feed mirroring.",
    images: ["/og-image.png"],
  },
  twitter: {
    card: "summary_large_image",
    title: "Reactive Cross-Chain Oracle",
    description:
      "Trustless, autonomous cross-chain price feeds powered by Reactive Network.",
  },
};


export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link href="https://api.fontshare.com/v2/css?f[]=clash-display@400,500,600&display=swap" rel="stylesheet" />
      </head>
      <body
        className={`font-clash antialiased`}
      >
        <Toaster position="top-right"/>
        <Web3Provider>{children}</Web3Provider>
      </body>
    </html>
  );
}
