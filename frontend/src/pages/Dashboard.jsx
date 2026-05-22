import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import Navbar from '../components/Navbar';
import WithdrawModal from '../components/WithdrawModal';

const NEON_COLOUR = { normal: '#e8e8f0', neon: '#6af7d0', mega_neon: '#f76af7' };
const NEON_LABEL  = { normal: '', neon: '✨ Neon', mega_neon: '🌈 Mega Neon' };

function PetCard({ pet }) {
  const colour = NEON_COLOUR[pet.neon_status] || '#e8e8f0';
  const isWithdrawing = pet.status === 'withdrawing';
  return (
    <div style={{
      background: '#16161e', border: `1px solid ${isWithdrawing ? '#7c6af7' : '#2a2a3a'}`,
      borderRadius: 10, padding: '16px 14px',
    }}>
      <div style={{ fontWeight: 700, fontSize: 14, color: colour, marginBottom: 2 }}>
        {NEON_LABEL[pet.neon_status] && <span style={{ marginRight: 4 }}>{NEON_LABEL[pet.neon_status]}</span>}
        {pet.pet_name}
      </div>
      <div style={{ fontSize: 11, color: '#777', textTransform: 'capitalize', marginBottom: 8 }}>
        {pet.age?.replace(/_/g, ' ')}
      </div>
      <span style={{
        display: 'inline-block', fontSize: 11, padding: '2px 8px', borderRadius: 20,
        background: isWithdrawing ? '#2a2060' : '#1a2a1a',
        color: isWithdrawing ? '#9c8af7' : '#4caf50',
      }}>
        {isWithdrawing ? 'Trade sent' : 'In bank'}
      </span>
    </div>
  );
}

function DepositBanner({ onDeposit }) {
  const [session, setSession]     = useState(null);
  const [loading, setLoading]     = useState(false);
  const [countdown, setCountdown] = useState(0);

  useEffect(() => {
    api.depositStatus().then(d => setSession(d.session)).catch(() => {});
  }, []);

  useEffect(() => {
    if (!session || session.status !== 'waiting') return;
    const tick = () => {
      const left = session.expires_at - Math.floor(Date.now() / 1000);
      setCountdown(Math.max(0, left));
      if (left <= 0) setSession(null);
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [session]);

  async function startDeposit() {
    setLoading(true);
    try {
      const d = await api.startDeposit();
      setSession({ ...d, status: 'waiting' });
      onDeposit();
    } catch (err) {
      alert(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function cancelDeposit() {
    await api.cancelDeposit().catch(() => {});
    setSession(null);
  }

  const mins = Math.floor(countdown / 60);
  const secs = String(countdown % 60).padStart(2, '0');

  if (session && session.status === 'waiting' && countdown > 0) {
    return (
      <div style={{ background: '#1a1a2e', border: '1px solid #7c6af7', borderRadius: 10, padding: '20px 22px', marginBottom: 32 }}>
        <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 6 }}>
          Deposit mode active — expires in {mins}:{secs}
        </div>
        <div style={{ fontSize: 13, color: '#aaa', marginBottom: 16, lineHeight: 1.6 }}>
          1. Open <strong>Adopt Me</strong> and find the bot account.<br />
          2. Send the bot a trade request.<br />
          3. Add your pets on your side. The bot gives nothing — it just accepts.<br />
          4. Confirm the trade. Your pets will appear here within seconds.
        </div>
        <button
          onClick={cancelDeposit}
          style={{ fontSize: 13, padding: '6px 14px', background: 'transparent', color: '#f66', border: '1px solid #f66', borderRadius: 6, cursor: 'pointer' }}
        >
          Cancel Deposit
        </button>
      </div>
    );
  }

  return (
    <div style={{ background: '#16161e', border: '1px dashed #7c6af7', borderRadius: 10, padding: '20px 22px', marginBottom: 32 }}>
      <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 6 }}>Deposit Pets into Bank</div>
      <div style={{ fontSize: 13, color: '#aaa', marginBottom: 16 }}>
        Click the button, then go to Adopt Me and trade your pets to the bot. Your pets will appear here once the trade is done.
      </div>
      <button
        onClick={startDeposit}
        disabled={loading}
        style={{ padding: '10px 22px', background: '#7c6af7', color: '#fff', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer' }}
      >
        {loading ? 'Starting…' : 'Start Deposit'}
      </button>
    </div>
  );
}

export default function Dashboard() {
  const [pets, setPets]           = useState([]);
  const [verifyStatus, setVS]     = useState(null);
  const [showWithdraw, setSW]     = useState(false);
  const [loading, setLoading]     = useState(true);
  const navigate = useNavigate();

  const reload = useCallback(async () => {
    const [inv, vs] = await Promise.all([
      api.getInventory().catch(() => ({ pets: [] })),
      api.verifyStatus().catch(() => null),
    ]);
    setPets(inv.pets);
    setVS(vs);
    setLoading(false);
  }, []);

  useEffect(() => { reload(); }, [reload]);

  // Poll every 5s while page is open so new deposits appear automatically
  useEffect(() => {
    const id = setInterval(() => api.getInventory().then(d => setPets(d.pets)).catch(() => {}), 5000);
    return () => clearInterval(id);
  }, []);

  if (loading) return <div><Navbar /><div style={{ padding: 40, color: '#888' }}>Loading…</div></div>;

  if (!verifyStatus?.verified) {
    return (
      <div>
        <Navbar />
        <div style={{ maxWidth: 600, margin: '80px auto', padding: '0 24px', textAlign: 'center' }}>
          <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 8 }}>Link your Roblox account first</div>
          <div style={{ fontSize: 14, color: '#888', marginBottom: 24 }}>Verification is required before you can deposit or withdraw.</div>
          <button style={{ padding: '12px 28px', background: '#7c6af7', color: '#fff', border: 'none', borderRadius: 8, fontSize: 15, fontWeight: 600, cursor: 'pointer' }} onClick={() => navigate('/verify')}>Verify Roblox Account</button>
        </div>
      </div>
    );
  }

  const inBank      = pets.filter(p => p.status === 'deposited');
  const withdrawing = pets.filter(p => p.status === 'withdrawing');

  return (
    <div>
      <Navbar />
      <div style={{ maxWidth: 920, margin: '0 auto', padding: '40px 24px' }}>

        <DepositBanner onDeposit={reload} />

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
          <div style={{ fontSize: 20, fontWeight: 700 }}>
            Bank — {inBank.length} pet{inBank.length !== 1 ? 's' : ''}
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <button style={{ padding: '9px 16px', background: 'transparent', color: '#aaa', border: '1px solid #2a2a3a', borderRadius: 7, fontSize: 13, cursor: 'pointer' }} onClick={reload}>Refresh</button>
            {inBank.length > 0 && (
              <button style={{ padding: '9px 16px', background: '#7c6af7', color: '#fff', border: 'none', borderRadius: 7, fontSize: 13, fontWeight: 600, cursor: 'pointer' }} onClick={() => setSW(true)}>Withdraw</button>
            )}
          </div>
        </div>

        {pets.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '60px 0', color: '#555' }}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>🐾</div>
            <div style={{ fontSize: 16, marginBottom: 6 }}>No pets in bank yet</div>
            <div style={{ fontSize: 13 }}>Click "Start Deposit" above to deposit your first pet.</div>
          </div>
        ) : (
          <>
            {inBank.length > 0 && (
              <div style={{ marginBottom: 36 }}>
                <div style={{ fontSize: 13, color: '#666', fontWeight: 600, marginBottom: 12, textTransform: 'uppercase', letterSpacing: 1 }}>Available</div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 }}>
                  {inBank.map(p => <PetCard key={p.id} pet={p} />)}
                </div>
              </div>
            )}

            {withdrawing.length > 0 && (
              <div>
                <div style={{ fontSize: 13, color: '#666', fontWeight: 600, marginBottom: 12, textTransform: 'uppercase', letterSpacing: 1 }}>Pending Withdrawal</div>
                <div style={{ fontSize: 13, color: '#aaa', background: '#1a1a24', borderRadius: 8, padding: '10px 14px', marginBottom: 12 }}>
                  Go to Adopt Me and send the bot a trade request — it will offer these pets back to you.
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 }}>
                  {withdrawing.map(p => <PetCard key={p.id} pet={p} />)}
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {showWithdraw && (
        <WithdrawModal pets={pets} onClose={() => setSW(false)} onSuccess={reload} />
      )}
    </div>
  );
}
