import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useAuth } from '../App';

const s = {
  wrap: { display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', padding: 24 },
  card: { background: '#16161e', border: '1px solid #2a2a3a', borderRadius: 12, padding: '36px 32px', width: '100%', maxWidth: 380 },
  title: { fontSize: 22, fontWeight: 700, marginBottom: 24, color: '#7c6af7' },
  field: { marginBottom: 16 },
  label: { display: 'block', fontSize: 13, color: '#aaa', marginBottom: 6 },
  input: { width: '100%', padding: '10px 12px', background: '#0f0f13', border: '1px solid #2a2a3a', borderRadius: 8, color: '#e8e8f0', fontSize: 14, outline: 'none' },
  btn: { width: '100%', padding: '12px', background: '#7c6af7', color: '#fff', border: 'none', borderRadius: 8, fontSize: 15, fontWeight: 600, cursor: 'pointer', marginTop: 8 },
  err: { color: '#f66', fontSize: 13, marginTop: 12 },
  link: { color: '#7c6af7', textDecoration: 'none' },
  foot: { marginTop: 20, fontSize: 13, color: '#aaa', textAlign: 'center' },
};

export default function Register() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  async function handleSubmit(e) {
    e.preventDefault();
    if (password !== confirm) return setError('Passwords do not match');
    setError('');
    setLoading(true);
    try {
      const data = await api.register(username, password);
      login(data.token, data.username);
      navigate('/verify');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={s.wrap}>
      <div style={s.card}>
        <div style={s.title}>Create Account</div>
        <form onSubmit={handleSubmit}>
          <div style={s.field}>
            <label style={s.label}>Username</label>
            <input style={s.input} value={username} onChange={e => setUsername(e.target.value)} required autoFocus />
          </div>
          <div style={s.field}>
            <label style={s.label}>Password</label>
            <input style={s.input} type="password" value={password} onChange={e => setPassword(e.target.value)} required />
          </div>
          <div style={s.field}>
            <label style={s.label}>Confirm Password</label>
            <input style={s.input} type="password" value={confirm} onChange={e => setConfirm(e.target.value)} required />
          </div>
          {error && <div style={s.err}>{error}</div>}
          <button style={s.btn} disabled={loading}>{loading ? 'Creating…' : 'Create Account'}</button>
        </form>
        <div style={s.foot}>Already have an account? <Link to="/login" style={s.link}>Log in</Link></div>
      </div>
    </div>
  );
}
