import Navbar from '@/components/Navbar'
import Hero from '@/components/Hero'
import FeaturedPets from '@/components/FeaturedPets'
import TrustSection from '@/components/TrustSection'
import Link from 'next/link'
import { ArrowRight } from 'lucide-react'

export default function Home() {
  return (
    <main className="min-h-screen">
      <Navbar />
      <Hero />
      <FeaturedPets />
      <TrustSection />

      {/* CTA Banner */}
      <section className="py-20 px-4">
        <div className="max-w-3xl mx-auto text-center">
          <div
            className="rounded-3xl p-10 relative overflow-hidden"
            style={{
              background: 'linear-gradient(135deg, #1a0a00, #0d0a1a)',
              border: '1px solid rgba(245,158,11,0.2)',
              boxShadow: '0 0 80px rgba(245,158,11,0.08)',
            }}
          >
            {/* Glow */}
            <div
              className="absolute inset-0 pointer-events-none"
              style={{
                background:
                  'radial-gradient(ellipse 80% 60% at 50% 0%, rgba(245,158,11,0.12) 0%, transparent 60%)',
              }}
            />

            <div className="relative z-10">
              <div className="text-5xl mb-4">🐉✨🦄</div>
              <h2 className="text-3xl sm:text-4xl font-black text-white mb-3">
                Ready to Own a{' '}
                <span className="gradient-text-gold">Legend?</span>
              </h2>
              <p className="text-slate-400 mb-8 max-w-xl mx-auto">
                Browse 50+ Adopt Me pets from Common to Mega Neon Legendary. Secure checkout in
                under 60 seconds.
              </p>
              <Link
                href="/shop"
                className="inline-flex items-center gap-2 bg-amber-500 hover:bg-amber-400 text-black font-black text-lg px-10 py-4 rounded-2xl transition-all hover:scale-105 active:scale-95 shadow-lg shadow-amber-500/20"
              >
                Shop All Pets
                <ArrowRight size={20} />
              </Link>
            </div>
          </div>
        </div>
      </section>

      <footer className="border-t border-white/5 py-8 px-4 text-center text-slate-700 text-xs">
        <p>
          🐾 AdoptStore — Not affiliated with Roblox or Adopt Me. Digital goods are third-party
          marketplace listings.
        </p>
        <p className="mt-1">Payments secured by Stripe. © {new Date().getFullYear()} AdoptStore.</p>
      </footer>
    </main>
  )
}
