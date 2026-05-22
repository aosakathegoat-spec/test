'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { ArrowRight, Sparkles } from 'lucide-react'
import Link from 'next/link'
import { pets } from '@/lib/pets'
import { RARITY_COLORS } from '@/lib/pets'
import type { Pet } from '@/lib/pets'
import BuyModal from './BuyModal'

const featured = pets.filter((p) => p.featured).slice(0, 5)

export default function FeaturedPets() {
  const [selectedPet, setSelectedPet] = useState<Pet | null>(null)

  return (
    <section className="py-20 px-4">
      <div className="max-w-7xl mx-auto">
        {/* Section header */}
        <div className="flex items-end justify-between mb-10">
          <div>
            <div className="flex items-center gap-2 text-amber-400 text-sm font-bold uppercase tracking-widest mb-2">
              <Sparkles size={14} />
              Featured Pets
            </div>
            <h2 className="text-3xl sm:text-4xl font-black text-white">
              Most Wanted
            </h2>
          </div>
          <Link
            href="/shop"
            className="hidden sm:flex items-center gap-1.5 text-slate-400 hover:text-white text-sm font-semibold transition-colors"
          >
            View all <ArrowRight size={15} />
          </Link>
        </div>

        {/* Featured cards — horizontal scroll on mobile, grid on desktop */}
        <div className="flex sm:grid sm:grid-cols-5 gap-4 overflow-x-auto pb-4 sm:pb-0 no-scrollbar">
          {featured.map((pet, i) => {
            const rarityColor = RARITY_COLORS[pet.rarity]
            return (
              <motion.div
                key={pet.id}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.08, duration: 0.4 }}
                className="flex-shrink-0 w-44 sm:w-auto cursor-pointer group"
                onClick={() => setSelectedPet(pet)}
              >
                <div
                  className="rounded-2xl overflow-hidden border transition-all group-hover:scale-[1.03] group-hover:-translate-y-1"
                  style={{
                    background: pet.bgColor,
                    borderColor: `${rarityColor}30`,
                    boxShadow: `0 0 30px ${rarityColor}15`,
                    transition: 'transform 0.2s ease, box-shadow 0.2s ease',
                  }}
                >
                  {/* Emoji */}
                  <div className="py-8 flex items-center justify-center">
                    <span
                      className="text-6xl float-a"
                      style={{
                        filter: `drop-shadow(0 0 24px ${rarityColor}80)`,
                        animationDelay: `${i * 0.7}s`,
                      }}
                    >
                      {pet.emoji}
                    </span>
                  </div>

                  {/* Info */}
                  <div className="px-3 pb-3">
                    <div
                      className="text-[10px] font-black uppercase tracking-widest mb-1"
                      style={{ color: rarityColor }}
                    >
                      {pet.rarity}
                    </div>
                    <div className="text-sm font-bold text-white">{pet.name}</div>
                    <div className="flex items-center justify-between mt-2">
                      <div className="text-base font-black text-white">
                        ${pet.basePrice.toFixed(2)}
                      </div>
                      <div
                        className="text-[10px] font-bold px-2 py-1 rounded-full"
                        style={{ background: `${rarityColor}20`, color: rarityColor }}
                      >
                        Buy →
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            )
          })}
        </div>

        <div className="mt-6 sm:hidden text-center">
          <Link
            href="/shop"
            className="inline-flex items-center gap-1.5 text-slate-400 hover:text-white text-sm font-semibold transition-colors"
          >
            View all pets <ArrowRight size={15} />
          </Link>
        </div>
      </div>

      <BuyModal pet={selectedPet} onClose={() => setSelectedPet(null)} />
    </section>
  )
}
