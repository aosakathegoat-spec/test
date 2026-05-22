import Link from 'next/link'
import Navbar from '@/components/Navbar'
import { CheckCircle, ArrowRight, Zap } from 'lucide-react'

export default function SuccessPage() {
  return (
    <main className="min-h-screen flex flex-col">
      <Navbar />

      <div className="flex-1 flex items-center justify-center px-4 py-20">
        <div className="text-center max-w-md">
          {/* Success animation */}
          <div className="relative mb-8 flex items-center justify-center">
            <div
              className="w-28 h-28 rounded-full flex items-center justify-center"
              style={{
                background: 'radial-gradient(circle, rgba(34,197,94,0.2) 0%, transparent 70%)',
                boxShadow: '0 0 60px rgba(34,197,94,0.3)',
              }}
            >
              <CheckCircle size={56} className="text-green-400" />
            </div>
            <div className="absolute inset-0 flex items-center justify-center">
              <div
                className="w-28 h-28 rounded-full border-2 border-green-500/30 animate-ping"
                style={{ animationDuration: '1.5s' }}
              />
            </div>
          </div>

          <div className="text-5xl mb-4">🎉</div>

          <h1 className="text-3xl font-black text-white mb-3">Payment Successful!</h1>

          <p className="text-slate-400 text-base mb-8 leading-relaxed">
            Your pet is on its way! Check your account — delivery typically takes{' '}
            <span className="text-amber-400 font-semibold">under 10 minutes</span>.
          </p>

          <div className="bg-green-950/30 border border-green-500/20 rounded-2xl p-5 mb-8 text-left">
            <div className="flex items-start gap-3">
              <Zap size={18} className="text-amber-400 mt-0.5 flex-shrink-0" />
              <div>
                <div className="text-sm font-bold text-white mb-1">What happens next?</div>
                <ul className="text-xs text-slate-400 space-y-1">
                  <li>✅ Payment confirmed</li>
                  <li>⏳ Our team is processing your order</li>
                  <li>🐾 Pet delivered to your Roblox account</li>
                  <li>📧 Confirmation email sent to you</li>
                </ul>
              </div>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row gap-3 justify-center">
            <Link
              href="/shop"
              className="flex items-center justify-center gap-2 bg-amber-500 hover:bg-amber-400 text-black font-bold px-6 py-3 rounded-xl transition-all hover:scale-105 active:scale-95"
            >
              Shop More Pets
              <ArrowRight size={16} />
            </Link>
            <Link
              href="/"
              className="flex items-center justify-center gap-2 bg-white/5 border border-white/10 text-white font-semibold px-6 py-3 rounded-xl transition-all hover:bg-white/10"
            >
              Back Home
            </Link>
          </div>
        </div>
      </div>
    </main>
  )
}
