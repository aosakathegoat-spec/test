'use client'

import { motion } from 'framer-motion'
import Link from 'next/link'
import { ArrowRight, Shield, Zap, Star } from 'lucide-react'

const FLOATING_PETS = [
  { emoji: '🐉', delay: 0, x: '8%', y: '25%', size: 72, dur: 'float-a' },
  { emoji: '🦄', delay: 1.5, x: '85%', y: '20%', size: 64, dur: 'float-b' },
  { emoji: '🦋', delay: 0.8, x: '75%', y: '65%', size: 48, dur: 'float-c' },
  { emoji: '🦊', delay: 2, x: '15%', y: '70%', size: 56, dur: 'float-a' },
  { emoji: '🐼', delay: 3, x: '92%', y: '48%', size: 44, dur: 'float-b' },
  { emoji: '🦩', delay: 1, x: '5%', y: '48%', size: 52, dur: 'float-c' },
  { emoji: '🦒', delay: 2.5, x: '55%', y: '80%', size: 40, dur: 'float-a' },
  { emoji: '🦜', delay: 0.3, x: '40%', y: '10%', size: 44, dur: 'float-b' },
]

const STATS = [
  { value: '50+', label: 'Pets' },
  { value: '12K+', label: 'Sold' },
  { value: '⭐ 4.9', label: 'Rating' },
]

export default function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
      {/* Background gradient */}
      <div className="absolute inset-0 bg-[#0a0a0f]" />
      <div
        className="absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse 80% 60% at 50% 0%, rgba(245,158,11,0.08) 0%, transparent 60%), radial-gradient(ellipse 60% 40% at 80% 80%, rgba(139,92,246,0.07) 0%, transparent 50%), radial-gradient(ellipse 50% 40% at 20% 80%, rgba(59,130,246,0.06) 0%, transparent 50%)',
        }}
      />

      {/* Grid pattern */}
      <div className="absolute inset-0 grid-pattern opacity-40" />

      {/* Floating pets */}
      {FLOATING_PETS.map((pet, i) => (
        <div
          key={i}
          className={`absolute pointer-events-none select-none ${pet.dur}`}
          style={{
            left: pet.x,
            top: pet.y,
            fontSize: pet.size,
            animationDelay: `${pet.delay}s`,
            filter: 'drop-shadow(0 0 20px rgba(245,158,11,0.3))',
            opacity: 0.7,
          }}
        >
          {pet.emoji}
        </div>
      ))}

      {/* Stars */}
      {Array.from({ length: 30 }).map((_, i) => (
        <div
          key={`star-${i}`}
          className="star absolute rounded-full bg-white pointer-events-none"
          style={{
            left: `${Math.random() * 100}%`,
            top: `${Math.random() * 100}%`,
            width: Math.random() < 0.5 ? '1px' : '2px',
            height: Math.random() < 0.5 ? '1px' : '2px',
            '--duration': `${2 + Math.random() * 3}s`,
            '--delay': `${Math.random() * 3}s`,
          } as React.CSSProperties}
        />
      ))}

      {/* Content */}
      <div className="relative z-10 text-center px-4 max-w-4xl mx-auto pt-20">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: 'easeOut' }}
        >
          {/* Badge */}
          <div className="inline-flex items-center gap-2 bg-amber-500/10 border border-amber-500/30 rounded-full px-4 py-1.5 text-amber-400 text-sm font-medium mb-6">
            <Zap size={13} className="fill-amber-400" />
            Instant Digital Delivery
          </div>

          {/* Title */}
          <h1 className="text-5xl sm:text-6xl md:text-7xl font-black leading-[1.05] mb-6 tracking-tight">
            Own the{' '}
            <span className="gradient-text">Rarest Pets</span>
            <br />
            in Adopt Me
          </h1>

          <p className="text-slate-400 text-lg sm:text-xl max-w-2xl mx-auto mb-10 leading-relaxed">
            Shop{' '}
            <span className="text-amber-400 font-semibold">50+ legendary, ultra-rare, and neon pets</span>
            {' '}with secure Stripe checkout. Every purchase delivered to your account in minutes.
          </p>

          {/* CTAs */}
          <div className="flex flex-col sm:flex-row gap-3 justify-center mb-14">
            <Link
              href="/shop"
              className="btn-glow group flex items-center justify-center gap-2 bg-amber-500 hover:bg-amber-400 text-black font-bold text-lg px-8 py-4 rounded-2xl transition-all hover:scale-105 active:scale-95 shadow-lg shadow-amber-500/20"
            >
              Browse All Pets
              <ArrowRight size={20} className="group-hover:translate-x-1 transition-transform" />
            </Link>
            <Link
              href="/shop?rarity=Legendary"
              className="flex items-center justify-center gap-2 bg-white/5 hover:bg-white/10 border border-white/10 text-white font-semibold text-lg px-8 py-4 rounded-2xl transition-all hover:scale-105 active:scale-95"
            >
              <Star size={18} className="text-amber-400" />
              Legendary Only
            </Link>
          </div>

          {/* Stats */}
          <div className="flex items-center justify-center gap-8 sm:gap-12">
            {STATS.map((s) => (
              <div key={s.label} className="text-center">
                <div className="text-2xl sm:text-3xl font-black text-white">{s.value}</div>
                <div className="text-xs text-slate-500 uppercase tracking-widest mt-0.5">{s.label}</div>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Trust badges */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8, duration: 0.5 }}
          className="flex flex-wrap items-center justify-center gap-4 mt-12 text-slate-500 text-xs"
        >
          <span className="flex items-center gap-1.5">
            <Shield size={13} className="text-green-500" />
            Stripe Secured
          </span>
          <span className="text-slate-700">•</span>
          <span className="flex items-center gap-1.5">
            <Zap size={13} className="text-amber-500" />
            Fast Delivery
          </span>
          <span className="text-slate-700">•</span>
          <span className="flex items-center gap-1.5">
            <Star size={13} className="text-amber-500" />
            4.9/5 Reviews
          </span>
        </motion.div>
      </div>

      {/* Bottom gradient fade */}
      <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-[#0a0a0f] to-transparent pointer-events-none" />
    </section>
  )
}
