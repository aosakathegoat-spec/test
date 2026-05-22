'use client'

import { useRef, useState } from 'react'
import { motion } from 'framer-motion'
import { Flame, Lock, Sparkles } from 'lucide-react'
import type { Pet } from '@/lib/pets'
import { RARITY_COLORS } from '@/lib/pets'

interface PetCardProps {
  pet: Pet
  onBuy: (pet: Pet) => void
  index?: number
}

export default function PetCard({ pet, onBuy, index = 0 }: PetCardProps) {
  const cardRef = useRef<HTMLDivElement>(null)
  const [tilt, setTilt] = useState({ x: 0, y: 0 })
  const [isHovered, setIsHovered] = useState(false)

  const rarityColor = RARITY_COLORS[pet.rarity]
  const isLegendary = pet.rarity === 'Legendary'
  const isUltraRare = pet.rarity === 'Ultra-Rare'

  function handleMouseMove(e: React.MouseEvent<HTMLDivElement>) {
    if (!cardRef.current) return
    const rect = cardRef.current.getBoundingClientRect()
    const x = (e.clientX - rect.left) / rect.width - 0.5
    const y = (e.clientY - rect.top) / rect.height - 0.5
    setTilt({ x: y * -14, y: x * 14 })
  }

  function handleMouseLeave() {
    setTilt({ x: 0, y: 0 })
    setIsHovered(false)
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: Math.min(index * 0.04, 0.5), duration: 0.4, ease: 'easeOut' }}
    >
      <div
        ref={cardRef}
        className="card-3d relative cursor-pointer rounded-2xl overflow-hidden select-none"
        style={{
          background: pet.bgColor,
          border: `1px solid ${rarityColor}30`,
          transform: `perspective(800px) rotateX(${tilt.x}deg) rotateY(${tilt.y}deg) scale(${isHovered ? 1.03 : 1})`,
          boxShadow: isHovered
            ? `0 20px 60px -10px ${rarityColor}40, 0 0 0 1px ${rarityColor}40`
            : `0 4px 20px -8px ${rarityColor}20`,
          transition: 'transform 0.15s ease-out, box-shadow 0.15s ease-out',
        }}
        onMouseMove={handleMouseMove}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={handleMouseLeave}
        onTouchStart={() => setIsHovered(true)}
        onTouchEnd={() => setIsHovered(false)}
        onClick={() => onBuy(pet)}
      >
        {/* Legendary shimmer overlay */}
        {isLegendary && (
          <div
            className="absolute inset-0 pointer-events-none z-10 legendary-shimmer"
            style={{ mixBlendMode: 'screen' }}
          />
        )}

        {/* Badges */}
        <div className="absolute top-2 left-2 z-20 flex flex-col gap-1">
          {pet.hot && (
            <span className="flex items-center gap-0.5 bg-red-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">
              <Flame size={9} />
              HOT
            </span>
          )}
          {pet.limited && (
            <span className="flex items-center gap-0.5 bg-black/50 border border-white/20 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">
              <Lock size={8} />
              LIMITED
            </span>
          )}
        </div>

        {/* Stock warning */}
        {pet.stock && pet.stock <= 5 && (
          <div className="absolute top-2 right-2 z-20">
            <span className="bg-red-950/80 border border-red-500/40 text-red-400 text-[10px] font-bold px-1.5 py-0.5 rounded-full whitespace-nowrap">
              {pet.stock} left!
            </span>
          </div>
        )}

        {/* Pet emoji */}
        <div className="relative pt-6 pb-2 flex items-center justify-center">
          <div
            className="float-a"
            style={{
              fontSize: 72,
              filter: `drop-shadow(0 0 20px ${rarityColor}60)`,
              lineHeight: 1,
            }}
          >
            {pet.emoji}
          </div>

          {/* Glow circle behind */}
          <div
            className="absolute inset-0 rounded-full pointer-events-none"
            style={{
              background: `radial-gradient(circle at 50% 60%, ${rarityColor}20 0%, transparent 65%)`,
            }}
          />
        </div>

        {/* Info */}
        <div className="px-3 pb-3 space-y-2">
          {/* Rarity badge */}
          <div className="flex items-center justify-between">
            <span
              className="text-[10px] font-black uppercase tracking-widest px-2 py-0.5 rounded-full"
              style={{
                color: rarityColor,
                background: `${rarityColor}15`,
                border: `1px solid ${rarityColor}30`,
              }}
            >
              {isLegendary && <Sparkles size={8} className="inline mr-0.5" />}
              {pet.rarity}
            </span>
          </div>

          <div>
            <h3 className="font-bold text-white text-sm leading-tight">{pet.name}</h3>
            <p className="text-slate-500 text-[11px] mt-0.5 leading-tight line-clamp-1">
              {pet.description}
            </p>
          </div>

          {/* Price + CTA */}
          <div className="flex items-center justify-between gap-2 pt-1">
            <div>
              <div className="text-[10px] text-slate-600 uppercase tracking-wider">From</div>
              <div className="text-base font-black text-white">
                ${pet.basePrice.toFixed(2)}
              </div>
            </div>

            <button
              className="btn-glow flex-1 font-bold text-xs py-2.5 px-3 rounded-xl transition-all active:scale-95"
              style={{
                background: isLegendary
                  ? 'linear-gradient(135deg, #f59e0b, #d97706)'
                  : isUltraRare
                  ? 'linear-gradient(135deg, #a855f7, #7c3aed)'
                  : `${rarityColor}`,
                color: isLegendary ? '#000' : '#fff',
                boxShadow: `0 4px 15px -4px ${rarityColor}60`,
              }}
              onClick={(e) => {
                e.stopPropagation()
                onBuy(pet)
              }}
            >
              Get It Now
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  )
}
