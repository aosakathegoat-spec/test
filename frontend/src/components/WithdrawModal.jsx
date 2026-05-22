import React, { useState } from 'react';
import { api } from '../api';

const overlay = {
  position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)',
  display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 16,
};
const modal = {
  background: '#16161e', border: '1px solid #2a2a3a', borderRadius: 12,
  padding: '28px 24px', width: '100%', maxWidth: 480, maxHeight: '80vh', overflowY: 'auto',
};
const s = {
  title: { fontSize: 18, fontWeight: 700, marginBottom: 4 },
  sub: { fontSize: 13, color: '#888', marginBottom: 20 },
  grid: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 20 },
  item: (selected) => ({
    padding: '12px 14px', background: selected ? '#2a2060' : '#0f0f13',
    border: `1px solid ${selected ? '#7c6af7' : '#2a2a3a'}`, borderRadius: 8,
    cursor: 'pointer', transition: 'all .15s',
  }),
  itemName: { fontSize: 13, fontWeight: 600, marginBottom: 2 },
  itemId: { fontSize: 11, color: '#666' },
  row: { display: 'flex', gap: 10, justifyContent: 'flex-end' },
  btn: { padding: '10px 20px', background: '#7c6af7', color: '#fff', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer' },
  btnCancel: { padding: '10px 20px', background: 'transparent', color: '#aaa', border: '1px solid #2a2a3a', borderRadius: 8, fontSize: 14, cursor: 'pointer' },
  err: { color: '#f66', fontSize: 13, marginBottom: 12 },
  ok: { color: '#4caf50', fontSize: 13, marginBottom: 12 },
  empty: { color: '#888', fontSize: 14, textAlign: 'center', padding: '20px 0' },
};

export default function WithdrawModal({ items, onClose, onSuccess }) {
  const [selected, setSelected] = useState(new Set());
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState(false);

  const available = items.filter(i => i.status === 'deposited');

  function toggle(id) {
    setSelected(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  async function handleWithdraw() {
    if (selected.size === 0) return setError('Select at least one item');
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
        <div style={s.title}>Withdraw Items</div>
        <div style={s.sub}>Select items to send back to your Roblox account. The bot will send a trade offer.</div>

        {done ? (
          <>
            <div style={s.ok}>Withdrawal requested! Check your Roblox trade offers — the bot will send a trade to you shortly.</div>
            <div style={s.row}><button style={s.btn} onClick={onClose}>Close</button></div>
          </>
        ) : (
          <>
            {available.length === 0 ? (
              <div style={s.empty}>No items available to withdraw.</div>
            ) : (
              <div style={s.grid}>
                {available.map(item => (
                  <div key={item.id} style={s.item(selected.has(item.id))} onClick={() => toggle(item.id)}>
                    <div style={s.itemName}>{item.asset_name}</div>
                    <div style={s.itemId}>Asset #{item.roblox_asset_id}</div>
                  </div>
                ))}
              </div>
            )}
            {error && <div style={s.err}>{error}</div>}
            <div style={s.row}>
              <button style={s.btnCancel} onClick={onClose}>Cancel</button>
              <button style={s.btn} onClick={handleWithdraw} disabled={loading || selected.size === 0}>
                {loading ? 'Requesting…' : `Withdraw ${selected.size > 0 ? `(${selected.size})` : ''}`}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
