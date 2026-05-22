import React, { useState } from 'react';
import { api } from '../api';

const overlay = {
  position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)',
  display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 16,
};
const modal = {
  background: '#16161e', border: '1px solid #2a2a3a', borderRadius: 12,
  padding: '28px 24px', width: '100%', maxWidth: 500, maxHeight: '80vh', overflowY: 'auto',
};

const NEON_COLOUR = { normal: '#aaa', neon: '#6af7d0', mega_neon: '#f76af7' };
const NEON_LABEL  = { normal: '', neon: 'Neon', mega_neon: 'Mega Neon' };

function PetCard({ pet, selected, onToggle }) {
  const colour = NEON_COLOUR[pet.neon_status] || '#aaa';
  return (
    <div
      onClick={onToggle}
      style={{
        padding: '12px 14px', borderRadius: 8, cursor: 'pointer',
        background: selected ? '#1e1a40' : '#0f0f13',
        border: `1px solid ${selected ? '#7c6af7' : '#2a2a3a'}`,
        transition: 'all .15s',
      }}
    >
      <div style={{ fontWeight: 600, fontSize: 13, color: colour }}>
        {NEON_LABEL[pet.neon_status] && <span style={{ marginRight: 4 }}>{NEON_LABEL[pet.neon_status]}</span>}
        {pet.pet_name}
      </div>
      <div style={{ fontSize: 11, color: '#666', marginTop: 2, textTransform: 'capitalize' }}>
        {pet.age?.replace(/_/g, ' ')}
      </div>
    </div>
  );
}

export default function WithdrawModal({ pets, onClose, onSuccess }) {
  const [selected, setSelected] = useState(new Set());
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState('');
  const [done, setDone]         = useState(false);

  const available = pets.filter(p => p.status === 'deposited');

  function toggle(id) {
    setSelected(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  async function handleWithdraw() {
    if (selected.size === 0) return setError('Select at least one pet');
    setError('');
    setLoading(true);
    try {
      await api.requestWithdraw([...selected]);
      setDone(true);
      onSuccess();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={overlay} onClick={e => e.target === e.currentTarget && onClose()}>
      <div style={modal}>
        <div style={{ fontSize: 18, fontWeight: 700, marginBottom: 4 }}>Withdraw Pets</div>
        <div style={{ fontSize: 13, color: '#888', marginBottom: 20 }}>
          Select pets to get back. Go to Adopt Me and send a trade request to the bot — it will offer your pets on its side.
        </div>

        {done ? (
          <>
            <div style={{ color: '#4caf50', fontSize: 14, marginBottom: 20 }}>
              Withdrawal requested! Go to Adopt Me, find the bot account, and send it a trade request. It will offer your selected pets back.
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button style={{ padding: '10px 20px', background: '#7c6af7', color: '#fff', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer' }} onClick={onClose}>Close</button>
            </div>
          </>
        ) : (
          <>
            {available.length === 0 ? (
              <div style={{ color: '#888', fontSize: 14, textAlign: 'center', padding: '20px 0' }}>No pets available to withdraw.</div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 20 }}>
                {available.map(pet => (
                  <PetCard key={pet.id} pet={pet} selected={selected.has(pet.id)} onToggle={() => toggle(pet.id)} />
                ))}
              </div>
            )}
            {error && <div style={{ color: '#f66', fontSize: 13, marginBottom: 12 }}>{error}</div>}
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
              <button style={{ padding: '10px 20px', background: 'transparent', color: '#aaa', border: '1px solid #2a2a3a', borderRadius: 8, fontSize: 14, cursor: 'pointer' }} onClick={onClose}>Cancel</button>
              <button
                style={{ padding: '10px 20px', background: '#7c6af7', color: '#fff', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer', opacity: selected.size === 0 ? 0.5 : 1 }}
                onClick={handleWithdraw}
                disabled={loading || selected.size === 0}
              >
                {loading ? 'Requesting…' : `Withdraw${selected.size > 0 ? ` (${selected.size})` : ''}`}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
