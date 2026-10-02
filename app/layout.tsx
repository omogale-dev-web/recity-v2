import type { Metadata } from "next";
import "./globals.css";
import "./recity.css";
import Pwa from "./pwa";

export const metadata: Metadata = {
  title: "RECITY — Waste Intelligence",
  description: "Understand waste and coordinate accountable collection.",
  manifest: "/manifest.webmanifest",
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}<Pwa/></body>
    </html>
  );
}


