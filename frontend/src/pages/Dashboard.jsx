import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import Navbar from '../components/Navbar';
import WithdrawModal from '../components/WithdrawModal';

const s = {
  page: { minHeight: '100vh' },
  wrap: { maxWidth: 900, margin: '0 auto', padding: '40px 24px' },
  header: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 32 },
  title: { fontSize: 22, fontWeight: 700 },
  actions: { display: 'flex', gap: 10 },
  btn: { padding: '10px 18px', background: '#7c6af7', color: '#fff', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer' },
  btnSec: { padding: '10px 18px', background: 'transparent', color: '#7c6af7', border: '1px solid #7c6af7', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer' },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 14, marginBottom: 40 },
  card: { background: '#16161e', border: '1px solid #2a2a3a', borderRadius: 10, padding: '16px 14px' },
  cardName: { fontWeight: 600, fontSize: 14, marginBottom: 4 },
  cardId: { fontSize: 11, color: '#666', marginBottom: 8 },
  badge: (status) => ({
    display: 'inline-block', fontSize: 11, padding: '2px 8px', borderRadius: 20,
    background: status === 'deposited' ? '#1a2e1a' : '#2a2060',
    color: status === 'deposited' ? '#4caf50' : '#9c8af7',
  }),
  empty: { textAlign: 'center', padding: '60px 0', color: '#666' },
  emptyTitle: { fontSize: 18, marginBottom: 8 },
  emptySub: { fontSize: 14, marginBottom: 24 },
  section: { marginBottom: 32 },
  sectionTitle: { fontSize: 16, fontWeight: 600, marginBottom: 16, color: '#aaa' },
  depositBox: { background: '#16161e', border: '1px dashed #7c6af7', borderRadius: 10, padding: '24px', marginBottom: 32 },
  depositTitle: { fontWeight: 600, marginBottom: 8 },
  depositDesc: { fontSize: 14, color: '#aaa', lineHeight: 1.6, marginBottom: 0 },
  botId: { fontFamily: 'monospace', color: '#7c6af7' },
  notice: { fontSize: 13, color: '#aaa', background: '#1a1a24', borderRadius: 8, padding: '12px 14px', marginBottom: 32 },
  noVerify: { textAlign: 'center', padding: '60px 0' },
  noVerifyTitle: { fontSize: 18, fontWeight: 600, marginBottom: 8 },
  noVerifySub: { fontSize: 14, color: '#aaa', marginBottom: 24 },
};

const BOT_USER_ID = import.meta.env.VITE_BOT_USER_ID || 'YOUR_BOT_ID';

export default function Dashboard() {
  const [items, setItems] = useState([]);
  const [verifyStatus, setVerifyStatus] = useState(null);
  const [showWithdraw, setShowWithdraw] = useState(false);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  const reload = useCallback(async () => {
    const [inv, vs] = await Promise.all([
      api.getInventory().catch(() => ({ items: [] })),
      api.verifyStatus().catch(() => null),
    ]);
    setItems(inv.items);
    setVerifyStatus(vs);
    setLoading(false);
  }, []);

  useEffect(() => { reload(); }, [reload]);

  if (loading) return <div style={s.page}><Navbar /><div style={{ padding: 40, color: '#888' }}>Loading…</div></div>;

  if (!verifyStatus?.verified) {
    return (
      <div style={s.page}>
        <Navbar />
        <div style={s.wrap}>
          <div style={s.noVerify}>
            <div style={s.noVerifyTitle}>Link your Roblox account first</div>
            <div style={s.noVerifySub}>You need to verify your Roblox account before you can deposit or withdraw items.</div>
            <button style={s.btn} onClick={() => navigate('/verify')}>Verify Roblox Account</button>
          </div>
        </div>
      </div>
    );
  }

  const deposited = items.filter(i => i.status === 'deposited');
  const withdrawing = items.filter(i => i.status === 'withdrawing');

  return (
    <div style={s.page}>
      <Navbar />
      <div style={s.wrap}>

        <div style={s.depositBox}>
          <div style={s.depositTitle}>How to Deposit</div>
          <div style={s.depositDesc}>
            Send a trade to the bot account (ID: <span style={s.botId}>{BOT_USER_ID}</span>).<br />
            Offer your items — <strong>the bot gives nothing in return</strong>.<br />
            Once the bot accepts the trade, your items will appear below automatically (within ~30 seconds).
          </div>
        </div>

        <div style={s.header}>
          <div style={s.title}>Your Escrow ({deposited.length} item{deposited.length !== 1 ? 's' : ''})</div>
          <div style={s.actions}>
            <button style={s.btnSec} onClick={reload}>Refresh</button>
            {deposited.length > 0 && (
              <button style={s.btn} onClick={() => setShowWithdraw(true)}>Withdraw Items</button>
            )}
          </div>
        </div>

        {items.length === 0 ? (
          <div style={s.empty}>
            <div style={s.emptyTitle}>No items deposited yet</div>
            <div style={s.emptySub}>Trade items to the bot to deposit them here.</div>
          </div>
        ) : (
          <>
            {deposited.length > 0 && (
              <div style={s.section}>
                <div style={s.sectionTitle}>Available ({deposited.length})</div>
                <div style={s.grid}>
                  {deposited.map(item => (
                    <div key={item.id} style={s.card}>
                      <div style={s.cardName}>{item.asset_name}</div>
                      <div style={s.cardId}>Asset #{item.roblox_asset_id}</div>
                      <span style={s.badge('deposited')}>In escrow</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {withdrawing.length > 0 && (
              <div style={s.section}>
                <div style={s.sectionTitle}>Pending Withdrawal ({withdrawing.length})</div>
                <div style={s.notice}>The bot is sending you a trade offer for these items. Check your Roblox trade notifications.</div>
                <div style={s.grid}>
                  {withdrawing.map(item => (
                    <div key={item.id} style={s.card}>
                      <div style={s.cardName}>{item.asset_name}</div>
                      <div style={s.cardId}>Asset #{item.roblox_asset_id}</div>
                      <span style={s.badge('withdrawing')}>Trade sent</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {showWithdraw && (
        <WithdrawModal
          items={items}
          onClose={() => setShowWithdraw(false)}
          onSuccess={reload}
        />
      )}
    </div>
  );
}
