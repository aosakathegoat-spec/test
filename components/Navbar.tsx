'use client'

import Link from 'next/link'
import { ShoppingBag } from 'lucide-react'

export default function Navbar() {
  return (
    <header className="fixed top-0 left-0 right-0 z-50">
      <div
        className="border-b border-white/5"
        style={{ background: 'rgba(10,10,15,0.85)', backdropFilter: 'blur(20px)' }}
      >
        <div className="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 font-bold text-lg">
            <span className="text-2xl">🐾</span>
            <span className="gradient-text-gold">AdoptStore</span>
          </Link>

          <nav className="hidden md:flex items-center gap-6 text-sm text-slate-400">
            <Link href="/shop" className="hover:text-white transition-colors">Shop All</Link>
            <Link href="/shop?rarity=Legendary" className="hover:text-amber-400 transition-colors">Legendary</Link>
            <Link href="/shop?rarity=Ultra-Rare" className="hover:text-purple-400 transition-colors">Ultra-Rare</Link>
          </nav>

          <div className="flex items-center gap-3">
            <Link
              href="/shop"
              className="hidden sm:flex items-center gap-2 bg-amber-500 hover:bg-amber-400 text-black font-bold text-sm px-4 py-2 rounded-full transition-all hover:scale-105 active:scale-95"
            >
              <ShoppingBag size={15} />
              Shop Now
            </Link>
            <Link
              href="/shop"
              className="sm:hidden flex items-center justify-center w-9 h-9 rounded-full bg-white/10 hover:bg-white/20 transition-colors"
            >
              <ShoppingBag size={18} />
            </Link>
          </div>
        </div>
      </div>
    </header>
  )
}
