import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

export const metadata: Metadata = {
  title: 'AdoptStore — Buy Adopt Me Pets Instantly',
  description:
    'Shop the largest collection of Adopt Me pets. Legendary dragons, unicorns, and more. Secure Stripe checkout, instant delivery.',
  keywords: 'adopt me pets, buy adopt me pets, shadow dragon, bat dragon, roblox pets',
  openGraph: {
    title: 'AdoptStore — Buy Adopt Me Pets Instantly',
    description: 'Own the rarest Adopt Me pets. Secure payment. Instant delivery.',
    type: 'website',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="bg-[#0a0a0f] text-slate-100 antialiased">{children}</body>
    </html>
  )
}
