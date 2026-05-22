'use client'

import { useState, useMemo, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import Navbar from '@/components/Navbar'
import PetCard from '@/components/PetCard'
import FilterBar from '@/components/FilterBar'
import BuyModal from '@/components/BuyModal'
import { pets } from '@/lib/pets'
import type { Pet, Rarity } from '@/lib/pets'

function ShopContent() {
  const searchParams = useSearchParams()
  const initialRarity = (searchParams.get('rarity') as Rarity) || 'All'

  const [search, setSearch] = useState('')
  const [rarity, setRarity] = useState<Rarity | 'All'>(initialRarity)
  const [hotOnly, setHotOnly] = useState(false)
  const [limitedOnly, setLimitedOnly] = useState(false)
  const [selectedPet, setSelectedPet] = useState<Pet | null>(null)

  const filtered = useMemo(() => {
    return pets.filter((p) => {
      if (rarity !== 'All' && p.rarity !== rarity) return false
      if (hotOnly && !p.hot) return false
      if (limitedOnly && !p.limited) return false
      if (search) {
        const q = search.toLowerCase()
        if (!p.name.toLowerCase().includes(q) && !p.rarity.toLowerCase().includes(q)) return false
      }
      return true
    })
  }, [search, rarity, hotOnly, limitedOnly])

  return (
    <main className="min-h-screen">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 pt-20">
        {/* Page header */}
        <div className="py-10">
          <h1 className="text-3xl sm:text-4xl font-black text-white mb-2">
            🐾 All Pets
          </h1>
          <p className="text-slate-500 text-sm">
            Every pet, every rarity. Tap to buy instantly.
          </p>
        </div>

        <FilterBar
          search={search}
          onSearch={setSearch}
          rarity={rarity}
          onRarity={setRarity}
          hotOnly={hotOnly}
          onHotToggle={() => setHotOnly((v) => !v)}
          limitedOnly={limitedOnly}
          onLimitedToggle={() => setLimitedOnly((v) => !v)}
          total={filtered.length}
        />

        {filtered.length === 0 ? (
          <div className="text-center py-20 text-slate-600">
            <div className="text-5xl mb-4">🔍</div>
            <div className="text-lg font-semibold text-slate-400">No pets found</div>
            <div className="text-sm mt-1">Try adjusting your filters</div>
          </div>
        ) : (
          <div className="pet-grid pb-20">
            {filtered.map((pet, i) => (
              <PetCard
                key={pet.id}
                pet={pet}
                index={i}
                onBuy={setSelectedPet}
              />
            ))}
          </div>
        )}
      </div>

      <BuyModal pet={selectedPet} onClose={() => setSelectedPet(null)} />
    </main>
  )
}

export default function ShopPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-[#0a0a0f]" />}>
      <ShopContent />
    </Suspense>
  )
}
