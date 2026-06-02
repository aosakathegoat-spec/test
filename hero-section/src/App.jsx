import { useEffect, useRef, useState, useCallback } from 'react'
import { motion, AnimatePresence } from 'motion/react'
import { Check } from 'lucide-react'
import './index.css'

// ─── useTypewriter hook ───────────────────────────────────────────────────────
function useTypewriter(text, speed = 38, startDelay = 600) {
  const [displayed, setDisplayed] = useState('')
  const [done, setDone] = useState(false)

  useEffect(() => {
    setDisplayed('')
    setDone(false)
    let index = 0
    let intervalId = null

    const delayTimer = setTimeout(() => {
      intervalId = setInterval(() => {
        index += 1
        setDisplayed(text.slice(0, index))
        if (index >= text.length) {
          clearInterval(intervalId)
          setDone(true)
        }
      }, speed)
    }, startDelay)

    return () => {
      clearTimeout(delayTimer)
      if (intervalId) clearInterval(intervalId)
    }
  }, [text, speed, startDelay])

  return { displayed, done }
}

// ─── BackgroundVideo ──────────────────────────────────────────────────────────
function BackgroundVideo() {
  const videoRef = useRef(null)

  // Desktop scrubbing: track ratio immediately, seek once duration is known
  useEffect(() => {
    const video = videoRef.current
    if (!video) return

    // Store 0-1 ratio even before video has loaded so we can snap on ready
    let ratio = 0
    let raf = null

    const doSeek = () => {
      const { duration } = video
      if (isFinite(duration) && duration > 0) {
        video.currentTime = ratio * duration
      }
      raf = null
    }

    // As soon as metadata arrives, jump to wherever the mouse already is
    const onReady = () => { if (!raf) raf = requestAnimationFrame(doSeek) }
    video.addEventListener('loadedmetadata', onReady)
    if (video.readyState >= 1) onReady()

    const onMove = (e) => {
      if (window.innerWidth < 768) return          // md breakpoint — works for any desktop window
      ratio = e.clientX / window.innerWidth
      const { duration } = video
      if (!isFinite(duration) || duration <= 0) return  // not ready yet; ratio stored, onReady will fire
      if (!raf) raf = requestAnimationFrame(doSeek)
    }

    window.addEventListener('mousemove', onMove, { passive: true })
    return () => {
      window.removeEventListener('mousemove', onMove)
      video.removeEventListener('loadedmetadata', onReady)
      if (raf) cancelAnimationFrame(raf)
    }
  }, [])

  // Mobile: autoplay + loop
  useEffect(() => {
    const video = videoRef.current
    if (!video) return

    const checkAndPlay = () => {
      if (window.innerWidth < 1024) {
        video.loop = true
        video.play().catch(() => {})
      }
    }

    checkAndPlay()
    window.addEventListener('resize', checkAndPlay)
    return () => window.removeEventListener('resize', checkAndPlay)
  }, [])

  return (
    <div className="order-last lg:order-none relative lg:absolute lg:inset-0 lg:z-0 overflow-hidden pointer-events-none w-full aspect-video lg:aspect-auto lg:h-full bg-neutral-100 lg:bg-transparent">
      <video
        ref={videoRef}
        muted
        playsInline
        preload="auto"
        className="w-full h-full object-cover object-center lg:object-right-bottom"
      >
        <source
          src="https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260601_110537_3a579fa0-7bbc-4d94-9d25-0e816c7840f5.mp4"
          type="video/mp4"
        />
      </video>
    </div>
  )
}

// ─── Navbar ───────────────────────────────────────────────────────────────────
function Navbar() {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)
  const links = ['Labs', 'Studio', 'Openings', 'Shop']

  return (
    <>
      <header className="fixed top-0 inset-x-0 z-10 px-5 sm:px-8 py-4 sm:py-5 flex flex-row justify-between items-center bg-transparent">
        {/* Logo */}
        <div className="flex flex-row items-center gap-3">
          <span className="text-[21px] sm:text-[26px] tracking-tight text-black font-medium select-none">
            Mainframe&reg;
          </span>
          <span className="text-[25px] sm:text-[30px] text-black select-none tracking-[-0.02em] font-medium leading-none mb-1">
            &#10033;
          </span>
        </div>

        {/* Desktop Nav */}
        <nav className="hidden md:flex flex-row items-center text-[23px] text-black">
          {links.map((link, i) => (
            <span key={link} className="flex items-center">
              <a href="#" className="hover:opacity-60 transition-opacity">{link}</a>
              {i < links.length - 1 && (
                <span className="opacity-40">,&nbsp;</span>
              )}
            </span>
          ))}
        </nav>

        {/* Desktop CTA */}
        <a
          href="#"
          className="hidden md:block text-[23px] text-black underline underline-offset-2 hover:opacity-60 transition-opacity"
        >
          Get in touch
        </a>

        {/* Hamburger */}
        <button
          className="md:hidden flex flex-col gap-[5px] justify-center items-center w-8 h-8 relative z-[11]"
          onClick={() => setIsMobileMenuOpen((v) => !v)}
          aria-label="Toggle menu"
        >
          <span
            className={`w-6 h-[2px] bg-black transition-all duration-300 origin-center ${
              isMobileMenuOpen ? 'rotate-45 translate-y-[7px]' : ''
            }`}
          />
          <span
            className={`w-6 h-[2px] bg-black transition-all duration-300 ${
              isMobileMenuOpen ? 'opacity-0' : ''
            }`}
          />
          <span
            className={`w-6 h-[2px] bg-black transition-all duration-300 origin-center ${
              isMobileMenuOpen ? '-rotate-45 -translate-y-[7px]' : ''
            }`}
          />
        </button>
      </header>

      {/* Mobile overlay */}
      <div
        className={`md:hidden fixed inset-0 z-[9] bg-white/95 backdrop-blur-sm flex flex-col items-center justify-center gap-8 transition-all duration-300 ${
          isMobileMenuOpen ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'
        }`}
      >
        {links.map((link) => (
          <a
            key={link}
            href="#"
            className="text-3xl text-black font-medium hover:opacity-60 transition-opacity"
            onClick={() => setIsMobileMenuOpen(false)}
          >
            {link}
          </a>
        ))}
        <a
          href="#"
          className="text-3xl text-black underline underline-offset-2 hover:opacity-60 transition-opacity"
          onClick={() => setIsMobileMenuOpen(false)}
        >
          Get in touch
        </a>
      </div>
    </>
  )
}

// ─── ServicePills ─────────────────────────────────────────────────────────────
const SERVICE_OPTIONS = ['Brand', 'Digital', 'Campaign', 'Other']

function ServicePills() {
  const [selected, setSelected] = useState([])

  const toggle = useCallback((service) => {
    setSelected((prev) =>
      prev.includes(service)
        ? prev.filter((s) => s !== service)
        : [...prev, service]
    )
  }, [])

  return (
    <div>
      <p className="text-2xl font-medium tracking-tight mb-2 text-black">
        What sort of service?
      </p>
      <p className="opacity-85 text-[#738273] mb-8">Select all that apply</p>

      <div className="flex flex-wrap gap-3 mb-6">
        {SERVICE_OPTIONS.map((service) => {
          const isActive = selected.includes(service)
          return (
            <motion.button
              key={service}
              onClick={() => toggle(service)}
              whileTap={{ scale: 0.96 }}
              className={`flex items-center gap-2 px-5 py-2.5 rounded-full text-sm font-medium transition-colors duration-200 cursor-pointer ${
                isActive
                  ? 'bg-[#1C2E1E] text-white shadow-md shadow-emerald-950/5'
                  : 'bg-white text-[#1C2E1E] border border-[#F1F3F1] hover:bg-[#F1F3F1]/55'
              }`}
            >
              <AnimatePresence>
                {isActive && (
                  <motion.span
                    initial={{ scale: 0, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    exit={{ scale: 0, opacity: 0 }}
                    transition={{ type: 'spring', stiffness: 300, damping: 20 }}
                    className="flex items-center"
                  >
                    <Check size={14} strokeWidth={2.5} />
                  </motion.span>
                )}
              </AnimatePresence>
              {service}
            </motion.button>
          )
        })}
      </div>

      {/* Feedback banner */}
      <AnimatePresence mode="wait">
        {selected.length === 0 ? (
          <motion.p
            key="placeholder"
            initial={{ opacity: 0 }}
            animate={{ opacity: 0.5 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="text-xs italic text-[#1C2E1E]"
          >
            Please click to select services above.
          </motion.p>
        ) : (
          <motion.div
            key="banner"
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.3, ease: 'easeOut' }}
            className="overflow-hidden"
          >
            <div className="bg-[#FAFBF9] border border-[#E8EBE8] rounded-2xl px-5 py-4 flex items-center justify-between gap-4">
              <p className="text-sm text-[#1C2E1E]">
                Ready to inquire about:{' '}
                <span className="font-medium">{selected.join(', ')}</span>
              </p>
              <a
                href="#"
                className="text-[#4D6D47] uppercase text-xs font-semibold tracking-wide whitespace-nowrap hover:opacity-70 transition-opacity"
              >
                Let's Go →
              </a>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

// ─── App ──────────────────────────────────────────────────────────────────────
export default function App() {
  const { displayed, done } = useTypewriter("we'd love to\nhear from you!", 38, 600)

  return (
    <div className="relative bg-white text-neutral-900 font-sans selection:bg-[#EAECE9] selection:text-[#1C2E1E] antialiased overflow-x-hidden flex flex-col lg:block lg:min-h-screen">
      <BackgroundVideo />
      <Navbar />

      {/* Content layer */}
      <div className="relative z-10 flex flex-col order-first lg:order-none w-full bg-white lg:bg-transparent pb-8 lg:pb-0 lg:min-h-screen">
        <main
          id="spade-hero"
          className="w-full max-w-7xl mx-auto px-6 pt-28 pb-12 lg:pt-0 lg:pb-0 flex-1 flex flex-col justify-center"
        >
          {/* Left-side content column — leaves right half free for video on desktop */}
          <div className="w-full lg:max-w-[52%]">
            {/* Headline */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
            >
              <h1 className="text-5xl md:text-6xl lg:text-[76px] font-normal tracking-tight text-black leading-[1.08] mb-8 select-none w-full whitespace-pre-wrap">
                {displayed}
                {!done && (
                  <span className="inline-block w-[2px] h-[1.1em] bg-black align-middle ml-[2px] animate-blink" />
                )}
              </h1>
            </motion.div>

            {/* Description */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.1 }}
            >
              <p className="text-lg md:text-xl text-[#5A635A] leading-relaxed font-normal mb-14 max-w-2xl">
                Whether you have questions, feedback, <br />
                drop us a message and we'll get back to you as soon as possible.
              </p>
            </motion.div>

            {/* Service Pills */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.2 }}
            >
              <ServicePills />
            </motion.div>
          </div>
        </main>
      </div>
    </div>
  )
}
