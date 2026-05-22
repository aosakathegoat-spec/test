'use client'

import { Flame, Star, Search, X } from 'lucide-react'
import type { Rarity } from '@/lib/pets'
import { RARITY_COLORS } from '@/lib/pets'

const RARITIES: Rarity[] = ['Common', 'Uncommon', 'Rare', 'Ultra-Rare', 'Legendary']

interface FilterBarProps {
  search: string
  onSearch: (v: string) => void
  rarity: Rarity | 'All'
  onRarity: (v: Rarity | 'All') => void
  hotOnly: boolean
  onHotToggle: () => void
  limitedOnly: boolean
  onLimitedToggle: () => void
  total: number
}

export default function FilterBar({
  search,
  onSearch,
  rarity,
  onRarity,
  hotOnly,
  onHotToggle,
  limitedOnly,
  onLimitedToggle,
  total,
}: FilterBarProps) {
  return (
    <div className="space-y-3 mb-6">
      {/* Search */}
      <div className="relative">
        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500" />
        <input
          type="text"
          value={search}
          onChange={(e) => onSearch(e.target.value)}
          placeholder="Search pets…"
          className="w-full bg-white/5 border border-white/10 rounded-xl pl-9 pr-9 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-amber-500/50 focus:bg-white/8 transition-all"
        />
        {search && (
          <button
            className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-white transition-colors"
            onClick={() => onSearch('')}
          >
            <X size={15} />
          </button>
        )}
      </div>

      {/* Rarity pills + quick filters */}
      <div className="flex gap-2 overflow-x-auto pb-1 no-scrollbar">
        <button
          onClick={() => onRarity('All')}
          className={`flex-shrink-0 px-3.5 py-1.5 rounded-full text-xs font-bold transition-all ${
            rarity === 'All'
              ? 'bg-white text-black'
              : 'bg-white/5 border border-white/10 text-slate-400 hover:text-white'
          }`}
        >
          All
        </button>

        {RARITIES.map((r) => {
          const color = RARITY_COLORS[r]
          const isActive = rarity === r
          return (
            <button
              key={r}
              onClick={() => onRarity(isActive ? 'All' : r)}
              className="flex-shrink-0 px-3.5 py-1.5 rounded-full text-xs font-bold transition-all"
              style={{
                background: isActive ? `${color}25` : 'rgba(255,255,255,0.05)',
                border: isActive ? `1px solid ${color}60` : '1px solid rgba(255,255,255,0.1)',
                color: isActive ? color : '#94a3b8',
              }}
            >
              {r}
            </button>
          )
        })}

        <button
          onClick={onHotToggle}
          className={`flex-shrink-0 flex items-center gap-1 px-3.5 py-1.5 rounded-full text-xs font-bold transition-all ${
            hotOnly
              ? 'bg-red-500/25 border border-red-500/60 text-red-400'
              : 'bg-white/5 border border-white/10 text-slate-400 hover:text-white'
          }`}
        >
          <Flame size={11} />
          Hot
        </button>

        <button
          onClick={onLimitedToggle}
          className={`flex-shrink-0 flex items-center gap-1 px-3.5 py-1.5 rounded-full text-xs font-bold transition-all ${
            limitedOnly
              ? 'bg-amber-500/25 border border-amber-500/60 text-amber-400'
              : 'bg-white/5 border border-white/10 text-slate-400 hover:text-white'
          }`}
        >
          <Star size={11} />
          Limited
        </button>
      </div>

      {/* Result count */}
      <div className="text-xs text-slate-600">
        Showing <span className="text-slate-400 font-semibold">{total}</span> pets
      </div>
    </div>
  )
}
