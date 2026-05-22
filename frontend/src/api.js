const BASE = '/api';

function getToken() { return localStorage.getItem('token'); }
function authHeaders() {
  return { 'Content-Type': 'application/json', Authorization: `Bearer ${getToken()}` };
}

async function request(path, options = {}) {
  const res = await fetch(BASE + path, options);
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}

export const api = {
  register: (username, password) =>
    request('/auth/register', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username, password }) }),

  login: (username, password) =>
    request('/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username, password }) }),

  verifyStatus: () => request('/verify/status', { headers: authHeaders() }),
  verifyStart:  (robloxUsername) =>
    request('/verify/start', { method: 'POST', headers: authHeaders(), body: JSON.stringify({ robloxUsername }) }),
  verifyConfirm: () => request('/verify/confirm', { method: 'POST', headers: authHeaders() }),

  getInventory: () => request('/inventory', { headers: authHeaders() }),

  startDeposit: () => request('/deposit/start', { method: 'POST', headers: authHeaders() }),
  cancelDeposit: () => request('/deposit/cancel', { method: 'POST', headers: authHeaders() }),
  depositStatus: () => request('/deposit/status', { headers: authHeaders() }),

  requestWithdraw: (petIds) =>
    request('/withdraw', { method: 'POST', headers: authHeaders(), body: JSON.stringify({ petIds }) }),
  withdrawHistory: () => request('/withdraw/history', { headers: authHeaders() }),
};
