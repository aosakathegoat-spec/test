import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import Navbar from '../components/Navbar';

const s = {
  page: { minHeight: '100vh' },
  wrap: { maxWidth: 520, margin: '60px auto', padding: '0 24px' },
  card: { background: '#16161e', border: '1px solid #2a2a3a', borderRadius: 12, padding: '32px 28px' },
  title: { fontSize: 20, fontWeight: 700, marginBottom: 8 },
  sub: { fontSize: 14, color: '#888', marginBottom: 28 },
  step: { display: 'flex', alignItems: 'flex-start', gap: 14, marginBottom: 24 },
  num: { minWidth: 28, height: 28, borderRadius: '50%', background: '#7c6af7', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, fontWeight: 700 },
  stepText: { flex: 1 },
  stepTitle: { fontWeight: 600, marginBottom: 4 },
  stepDesc: { fontSize: 13, color: '#aaa', lineHeight: 1.5 },
  code: {
    display: 'inline-block', background: '#0f0f13', border: '1px solid #7c6af7',
    borderRadius: 6, padding: '6px 14px', fontFamily: 'monospace', fontSize: 15,
    color: '#7c6af7', letterSpacing: 2, marginTop: 6, cursor: 'pointer', userSelect: 'all',
  },
  field: { marginBottom: 16 },
  label: { display: 'block', fontSize: 13, color: '#aaa', marginBottom: 6 },
  input: { width: '100%', padding: '10px 12px', background: '#0f0f13', border: '1px solid #2a2a3a', borderRadius: 8, color: '#e8e8f0', fontSize: 14, outline: 'none' },
  btn: { padding: '10px 20px', background: '#7c6af7', color: '#fff', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer' },
  btnSec: { padding: '10px 20px', background: 'transparent', color: '#7c6af7', border: '1px solid #7c6af7', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer' },
  err: { color: '#f66', fontSize: 13, marginTop: 10 },
  ok: { color: '#4caf50', fontSize: 13, marginTop: 10 },
  verified: { textAlign: 'center', padding: '32px 0' },
  verifiedIcon: { fontSize: 48, marginBottom: 12 },
  verifiedText: { fontSize: 18, fontWeight: 700, marginBottom: 6 },
  verifiedSub: { color: '#aaa', fontSize: 14, marginBottom: 24 },
};

export default function Verify() {
  const [status, setStatus] = useState(null);
  const [robloxUsername, setRobloxUsername] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    api.verifyStatus().then(setStatus).catch(() => {});
  }, []);

  async function handleStart(e) {
    e.preventDefault();
    setError(''); setSuccess('');
    setLoading(true);
    try {
      const data = await api.verifyStart(robloxUsername);
      setCode(data.code);
      setStatus({ linked: true, verified: false, verificationCode: data.code, robloxUsername: data.robloxUsername });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleConfirm() {
    setError(''); setSuccess('');
    setLoading(true);
    try {
      await api.verifyConfirm();
      setSuccess('Roblox account verified!');
      setStatus(s => ({ ...s, verified: true }));
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  if (!status) return <div style={s.page}><Navbar /><div style={{ padding: 40, color: '#888' }}>Loading…</div></div>;

  if (status.verified) {
    return (
      <div style={s.page}>
        <Navbar />
        <div style={s.wrap}>
          <div style={s.card}>
            <div style={s.verified}>
              <div style={s.verifiedIcon}>✅</div>
              <div style={s.verifiedText}>Verified as {status.robloxUsername}</div>
              <div style={s.verifiedSub}>Your Roblox account is linked. You can now deposit and withdraw items.</div>
              <button style={s.btn} onClick={() => navigate('/dashboard')}>Go to Dashboard</button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  const currentCode = status.verificationCode || code;

  return (
    <div style={s.page}>
      <Navbar />
      <div style={s.wrap}>
        <div style={s.card}>
          <div style={s.title}>Link Your Roblox Account</div>
          <div style={s.sub}>Verify ownership so the bot knows which deposits belong to you.</div>

          {!currentCode ? (
            <form onSubmit={handleStart}>
              <div style={s.step}>
                <div style={s.num}>1</div>
                <div style={s.stepText}>
                  <div style={s.stepTitle}>Enter your Roblox username</div>
                  <div style={s.stepDesc}>We'll generate a unique code for you to paste in your bio.</div>
                </div>
              </div>
              <div style={s.field}>
                <label style={s.label}>Roblox Username</label>
                <input
                  style={s.input}
                  value={robloxUsername}
                  onChange={e => setRobloxUsername(e.target.value)}
                  placeholder="YourRobloxName"
                  required
                  autoFocus
                />
              </div>
              {error && <div style={s.err}>{error}</div>}
              <button style={s.btn} disabled={loading}>{loading ? 'Looking up…' : 'Get Verification Code'}</button>
            </form>
          ) : (
            <>
              <div style={s.step}>
                <div style={s.num}>1</div>
                <div style={s.stepText}>
                  <div style={s.stepTitle}>Copy your verification code</div>
                  <div style={s.stepDesc}>Click to copy, then paste it anywhere in your Roblox profile's About section.</div>
                  <div
                    style={s.code}
                    onClick={() => navigator.clipboard.writeText(currentCode)}
                    title="Click to copy"
                  >
                    {currentCode}
                  </div>
                </div>
              </div>

              <div style={s.step}>
                <div style={s.num}>2</div>
                <div style={s.stepText}>
                  <div style={s.stepTitle}>Update your Roblox bio</div>
                  <div style={s.stepDesc}>
                    Go to <strong>roblox.com → Profile → Edit → About</strong>, paste the code, and save.
                  </div>
                </div>
              </div>

              <div style={s.step}>
                <div style={s.num}>3</div>
                <div style={s.stepText}>
                  <div style={s.stepTitle}>Click Verify below</div>
                  <div style={s.stepDesc}>We'll check your bio for the code to confirm you own the account.</div>
                </div>
              </div>

              {error && <div style={s.err}>{error}</div>}
              {success && <div style={s.ok}>{success}</div>}
              <div style={{ display: 'flex', gap: 10 }}>
                <button style={s.btn} onClick={handleConfirm} disabled={loading}>
                  {loading ? 'Checking…' : 'Verify'}
                </button>
                <button style={s.btnSec} onClick={() => { setCode(''); setStatus(s => ({ ...s, verificationCode: null })); }}>
                  Change account
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
