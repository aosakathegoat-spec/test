import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../App';

const s = {
  nav: {
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '0 24px', height: 56, background: '#16161e',
    borderBottom: '1px solid #2a2a3a', position: 'sticky', top: 0, zIndex: 10,
  },
  logo: { fontWeight: 700, fontSize: 18, color: '#7c6af7', textDecoration: 'none' },
  right: { display: 'flex', alignItems: 'center', gap: 16 },
  user: { fontSize: 14, color: '#aaa' },
  btn: {
    fontSize: 13, padding: '6px 14px', borderRadius: 6,
    background: '#7c6af7', color: '#fff', border: 'none', cursor: 'pointer',
  },
};

export default function Navbar() {
  const { username, logout } = useAuth();
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate('/login');
  }

  return (
    <nav style={s.nav}>
      <Link to="/dashboard" style={s.logo}>RobloxEscrow</Link>
      <div style={s.right}>
        <span style={s.user}>{username}</span>
        <Link to="/verify" style={{ ...s.btn, background: 'transparent', border: '1px solid #7c6af7', color: '#7c6af7', textDecoration: 'none', fontSize: 13, padding: '6px 14px', borderRadius: 6 }}>Roblox Account</Link>
        <button style={s.btn} onClick={handleLogout}>Log out</button>
      </div>
    </nav>
  );
}
