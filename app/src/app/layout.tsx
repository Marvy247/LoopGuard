import type { Metadata } from "next";
import "./globals.css";
import { Toaster } from 'react-hot-toast';
import { Web3Provider } from "@/providers/Web3Provider";

export const metadata: Metadata = {
  title: "LoopGuard - Your Position's 24/7 Guardian",
  description:
    "Leveraged looping protocol with autonomous liquidation defense. Build leveraged positions on Aave V3 with 24/7 reactive monitoring to prevent liquidations.",
  keywords:
    "reactive contracts, defi, leveraged looping, aave, liquidation protection, defi automation, ethereum, sepolia",
  openGraph: {
    title: "LoopGuard - Your Position's 24/7 Guardian",
    description:
      "The first self-defending leveraged position protocol powered by Reactive Network.",
    images: ["/og-image.png"],
  },
  twitter: {
    card: "summary_large_image",
    title: "LoopGuard Protocol",
    description:
      "Autonomous 24/7 liquidation protection for your leveraged positions.",
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
