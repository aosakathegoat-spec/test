'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X, Shield, Zap, ChevronDown, ChevronUp } from 'lucide-react'
import type { Pet, PetVariant } from '@/lib/pets'
import { RARITY_COLORS, VARIANT_MULTIPLIERS, VARIANT_LABELS, getPetPrice } from '@/lib/pets'
import { loadStripe } from '@stripe/stripe-js'

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)

const ALL_VARIANTS: PetVariant[] = ['Normal', 'Fly', 'Ride', 'Fly Ride', 'Neon', 'Mega Neon']

interface BuyModalProps {
  pet: Pet | null
  onClose: () => void
}

export default function BuyModal({ pet, onClose }: BuyModalProps) {
  const [variant, setVariant] = useState<PetVariant>('Normal')
  const [quantity, setQuantity] = useState(1)
  const [loading, setLoading] = useState(false)
  const [showVariants, setShowVariants] = useState(false)

  if (!pet) return null

  const rarityColor = RARITY_COLORS[pet.rarity]
  const unitPrice = getPetPrice(pet, variant)
  const total = Math.round(unitPrice * quantity * 100) / 100
  const isLegendary = pet.rarity === 'Legendary'

  async function handleCheckout() {
    setLoading(true)
    try {
      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ petId: pet!.id, variant, quantity }),
      })
      const { url, error } = await res.json()
      if (error) throw new Error(error)
      window.location.href = url
    } catch (err) {
      console.error(err)
      setLoading(false)
    }
  }

  return (
    <AnimatePresence>
      {pet && (
        <>
          {/* Overlay */}
          <motion.div
            className="fixed inset-0 z-50 bg-black/70"
            style={{ backdropFilter: 'blur(8px)' }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />

          {/* Sheet — slides up from bottom on mobile, centered on desktop */}
          <motion.div
            className="fixed z-50 left-0 right-0 bottom-0 sm:inset-0 sm:flex sm:items-center sm:justify-center sm:p-4"
            initial={false}
          >
            <motion.div
              className="relative w-full sm:max-w-md bg-[#12121a] sm:rounded-2xl rounded-t-3xl overflow-hidden border border-white/10 safe-bottom"
              initial={{ y: '100%', opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: '100%', opacity: 0 }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              onClick={(e) => e.stopPropagation()}
            >
              {/* Glow top */}
              <div
                className="absolute top-0 left-0 right-0 h-1"
                style={{ background: `linear-gradient(90deg, transparent, ${rarityColor}, transparent)` }}
              />

              {/* Handle (mobile) */}
              <div className="flex justify-center pt-3 pb-1 sm:hidden">
                <div className="w-10 h-1 rounded-full bg-white/20" />
              </div>

              {/* Close button */}
              <button
                className="absolute top-4 right-4 w-8 h-8 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 transition-colors"
                onClick={onClose}
              >
                <X size={16} />
              </button>

              <div className="px-5 pt-4 pb-6">
                {/* Pet preview */}
                <div className="flex items-center gap-4 mb-6">
                  <div
                    className="w-20 h-20 rounded-2xl flex items-center justify-center text-5xl float-a flex-shrink-0"
                    style={{
                      background: pet.bgColor,
                      border: `1px solid ${rarityColor}40`,
                      boxShadow: `0 0 30px ${rarityColor}30`,
                    }}
                  >
                    {pet.emoji}
                  </div>
                  <div>
                    <div
                      className="text-xs font-black uppercase tracking-widest mb-1"
                      style={{ color: rarityColor }}
                    >
                      {pet.rarity}
                    </div>
                    <h2 className="text-xl font-black text-white">{pet.name}</h2>
                    <p className="text-slate-500 text-xs mt-0.5 leading-snug line-clamp-2">
                      {pet.description}
                    </p>
                  </div>
                </div>

                {/* Variant selector */}
                <div className="mb-4">
                  <button
                    className="w-full flex items-center justify-between bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm font-semibold text-white hover:bg-white/8 transition-colors"
                    onClick={() => setShowVariants(!showVariants)}
                  >
                    <span>{VARIANT_LABELS[variant]}</span>
                    <div className="flex items-center gap-2">
                      <span className="text-slate-400 font-normal text-xs">
                        {variant !== 'Normal' && `×${VARIANT_MULTIPLIERS[variant]}`}
                      </span>
                      {showVariants ? <ChevronUp size={16} className="text-slate-400" /> : <ChevronDown size={16} className="text-slate-400" />}
                    </div>
                  </button>

                  <AnimatePresence>
                    {showVariants && (
                      <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.2 }}
                        className="overflow-hidden"
                      >
                        <div className="mt-1 grid grid-cols-2 gap-1.5 p-1 bg-white/3 rounded-xl border border-white/5">
                          {ALL_VARIANTS.map((v) => {
                            const isSelected = variant === v
                            const price = getPetPrice(pet, v)
                            return (
                              <button
                                key={v}
                                onClick={() => {
                                  setVariant(v)
                                  setShowVariants(false)
                                }}
                                className="flex flex-col items-start px-3 py-2 rounded-lg transition-all text-left"
                                style={{
                                  background: isSelected ? `${rarityColor}20` : 'transparent',
                                  border: isSelected ? `1px solid ${rarityColor}50` : '1px solid transparent',
                                }}
                              >
                                <span className="text-xs font-bold text-white">{VARIANT_LABELS[v]}</span>
                                <span className="text-[11px] text-slate-400">${price.toFixed(2)}</span>
                              </button>
                            )
                          })}
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>

                {/* Quantity */}
                <div className="mb-5">
                  <label className="text-xs text-slate-500 uppercase tracking-widest font-bold mb-2 block">
                    Quantity
                  </label>
                  <div className="flex items-center gap-3">
                    {[1, 2, 3, 5, 10].map((q) => (
                      <button
                        key={q}
                        onClick={() => setQuantity(q)}
                        className="flex-1 py-2.5 rounded-xl text-sm font-bold transition-all"
                        style={{
                          background: quantity === q ? `${rarityColor}25` : 'rgba(255,255,255,0.05)',
                          border: quantity === q ? `1px solid ${rarityColor}60` : '1px solid transparent',
                          color: quantity === q ? rarityColor : '#94a3b8',
                        }}
                      >
                        {q}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Total */}
                <div
                  className="flex items-center justify-between rounded-xl p-4 mb-4"
                  style={{ background: `${rarityColor}10`, border: `1px solid ${rarityColor}25` }}
                >
                  <div>
                    <div className="text-xs text-slate-400">
                      {quantity} × {pet.name} ({variant})
                    </div>
                    <div className="text-xs text-slate-500 mt-0.5">
                      ${unitPrice.toFixed(2)} each
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-xs text-slate-400 uppercase tracking-widest">Total</div>
                    <div className="text-2xl font-black text-white">${total.toFixed(2)}</div>
                  </div>
                </div>

                {/* CTA */}
                <button
                  disabled={loading}
                  onClick={handleCheckout}
                  className="btn-glow w-full font-black text-base py-4 rounded-2xl transition-all hover:scale-[1.02] active:scale-[0.98] disabled:opacity-60 disabled:scale-100"
                  style={{
                    background: isLegendary
                      ? 'linear-gradient(135deg, #f59e0b, #d97706)'
                      : `linear-gradient(135deg, ${rarityColor}, ${rarityColor}aa)`,
                    color: isLegendary ? '#000' : '#fff',
                    boxShadow: `0 8px 30px -6px ${rarityColor}60`,
                  }}
                >
                  {loading ? (
                    <span className="flex items-center justify-center gap-2">
                      <span className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
                      Processing…
                    </span>
                  ) : (
                    `Buy Now — $${total.toFixed(2)}`
                  )}
                </button>

                {/* Trust row */}
                <div className="flex items-center justify-center gap-4 mt-3 text-slate-600 text-[11px]">
                  <span className="flex items-center gap-1">
                    <Shield size={11} className="text-green-500" /> Secure
                  </span>
                  <span className="flex items-center gap-1">
                    <Zap size={11} className="text-amber-500" /> Instant
                  </span>
                  <span className="text-slate-700">Powered by Stripe</span>
                </div>
              </div>
            </motion.div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  )
}
