'use client'

import { motion } from 'framer-motion'
import { Shield, Zap, Clock, Star, Users, Lock } from 'lucide-react'

const TRUST_ITEMS = [
  {
    icon: <Shield size={24} />,
    color: '#22c55e',
    title: 'Stripe Secured',
    desc: '256-bit SSL encryption on every payment.',
  },
  {
    icon: <Zap size={24} />,
    color: '#f59e0b',
    title: 'Instant Delivery',
    desc: 'Pets delivered to your account within minutes.',
  },
  {
    icon: <Clock size={24} />,
    color: '#3b82f6',
    title: '24/7 Support',
    desc: 'Real humans ready to help anytime.',
  },
  {
    icon: <Star size={24} />,
    color: '#ec4899',
    title: '4.9/5 Rating',
    desc: 'Over 12,000 happy customers worldwide.',
  },
  {
    icon: <Users size={24} />,
    color: '#a855f7',
    title: 'Trusted Community',
    desc: 'Verified sellers with thousands of trades.',
  },
  {
    icon: <Lock size={24} />,
    color: '#14b8a6',
    title: 'Guaranteed Safe',
    desc: 'Every pet guaranteed authentic or full refund.',
  },
]

export default function TrustSection() {
  return (
    <section className="py-20 px-4 relative overflow-hidden">
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background: 'radial-gradient(ellipse 60% 50% at 50% 50%, rgba(245,158,11,0.04) 0%, transparent 70%)',
        }}
      />

      <div className="max-w-6xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="text-center mb-12"
        >
          <h2 className="text-3xl sm:text-4xl font-black text-white mb-3">
            Why 12,000+ Players Choose Us
          </h2>
          <p className="text-slate-500">Shop with confidence. Every trade backed by our guarantee.</p>
        </motion.div>

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
          {TRUST_ITEMS.map((item, i) => (
            <motion.div
              key={item.title}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.07 }}
              className="flex items-start gap-3 bg-white/3 border border-white/8 rounded-2xl p-4 hover:bg-white/5 transition-colors"
            >
              <div
                className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
                style={{ background: `${item.color}15`, color: item.color }}
              >
                {item.icon}
              </div>
              <div>
                <div className="text-sm font-bold text-white mb-0.5">{item.title}</div>
                <div className="text-xs text-slate-500 leading-snug">{item.desc}</div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}
