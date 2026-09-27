import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { createClient } from '@supabase/supabase-js';
import './style.css';

const supabase = createClient(import.meta.env.VITE_SUPABASE_URL, import.meta.env.VITE_SUPABASE_ANON_KEY);
const VERSION = 'ZenexPay Admin v7.0 Production';
const money = (v) => `৳ ${Number(v || 0).toFixed(2)}`;
const dateText = (v) => (v ? new Date(v).toLocaleString() : '-');
const shortId = (v) => (v ? `${String(v).slice(0, 8)}…` : '-');
const maskAccount = (v) => {
  const s = String(v || '');
  if (s.length <= 4) return s ? '••••' : '-';
  return `${'•'.repeat(Math.max(2, s.length - 4))}${s.slice(-4)}`;
};

async function rows(table, columns = '*', options = {}) {
  let q = supabase.from(table).select(columns);
  if (options.order) q = q.order(options.order, { ascending: options.ascending ?? false });
  if (options.limit) q = q.limit(options.limit);
  const { data, error } = await q;
  if (error) throw error;
  return data || [];
}
function friendlyError(error) { return error?.message || 'Unknown error'; }

function App() {
  const [session, setSession] = useState(null);
  const [adminRole, setAdminRole] = useState(null);
  const [checking, setChecking] = useState(true);
  const [page, setPage] = useState('dashboard');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [data, setData] = useState({ users: [], wallets: [], tasks: [], submissions: [], withdrawals: [], transactions: [], promotions: [], missions: [], notifications: [], support: [], audit: [], settings: {} });
  const [selectedUser, setSelectedUser] = useState(null);
  const [search, setSearch] = useState('');
  const [busy, setBusy] = useState('');
  const [metrics, setMetrics] = useState(null);

  useEffect(() => {
    let active = true;
    supabase.auth.getSession().then(async ({ data: d }) => {
      if (!active) return;
      setSession(d.session);
      if (d.session) {
        try {
          const allowed = await rpc('is_admin');
          if (!allowed) { await supabase.auth.signOut(); setSession(null); setAdminRole(null); setMessage('This Admin account is inactive or not authorized.'); setChecking(false); return; }
          setAdminRole(await rpc('admin_role_for', { p_user_id: d.session.user.id }));
        } catch (_) { setAdminRole(null); }
      }
      setChecking(false);
    }).catch(() => setChecking(false));
    const { data: listener } = supabase.auth.onAuthStateChange(async (_event, next) => {
      setSession(next);
      if (next) {
        try {
          const allowed = await rpc('is_admin');
          if (!allowed) { await supabase.auth.signOut(); setSession(null); setAdminRole(null); setMessage('This Admin account is inactive or not authorized.'); return; }
          setAdminRole(await rpc('admin_role_for', { p_user_id: next.user.id }));
        } catch (_) { setAdminRole(null); }
      } else setAdminRole(null);
    });
    return () => { active = false; listener.subscription.unsubscribe(); };
  }, []);

  useEffect(() => { if (session && adminRole) loadAll(); }, [session, adminRole]);

  useEffect(() => {
    if (!session) return undefined;
    let alive = true;
    const channel = supabase.channel('zenexpay-admin-live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'withdrawals' }, () => { if (alive) refreshLive(); })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'task_submissions' }, () => { if (alive) refreshLive(); })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'support_messages' }, () => { if (alive) refreshLive(); })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => { if (alive) refreshLive(); })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'app_settings' }, () => { if (alive) refreshLive(); })
      .subscribe();
    return () => { alive = false; supabase.removeChannel(channel); };
  }, [session]);

  useEffect(() => {
    if (!session) return undefined;
    let timer;
    const reset = () => {
      clearTimeout(timer);
      timer = setTimeout(() => logout(), 30 * 60 * 1000);
    };
    const events = ['mousedown', 'keydown', 'touchstart', 'scroll'];
    events.forEach((e) => window.addEventListener(e, reset, { passive: true }));
    reset();
    return () => { clearTimeout(timer); events.forEach((e) => window.removeEventListener(e, reset)); };
  }, [session]);

  async function refreshLive() {
    try {
      const [withdrawals, submissions, support, users, settingsRows, audit] = await Promise.all([
        rows('withdrawals', '*', { order: 'created_at', limit: 500 }),
        rows('task_submissions', '*', { order: 'created_at', limit: 500 }),
        rows('support_messages', '*', { order: 'created_at', limit: 500 }),
        rows('profiles', '*', { order: 'created_at', limit: 500 }),
        rows('app_settings'),
        rows('user_activity_audit', '*', { order: 'created_at', limit: 500 }),
      ]);
      setData((old) => ({ ...old, withdrawals, submissions, support, users, audit, settings: Object.fromEntries(settingsRows.map((x) => [x.key, x.value])) }));
      loadMetrics(false);
    } catch (_) { /* Live updates are best-effort; manual refresh remains available. */ }
  }

  async function loadMetrics(showError = true) {
    try { const result = await rpc('admin_dashboard_metrics'); setMetrics(result || null); }
    catch (e) { if (showError) setMessage(`Metrics failed: ${friendlyError(e)}`); }
  }

  async function loadAll() {
    setLoading(true);
    const next = { users: [], wallets: [], tasks: [], submissions: [], withdrawals: [], transactions: [], promotions: [], missions: [], notifications: [], support: [], audit: [], settings: {} };
    const all = adminRole === 'super_admin';
    const jobs = [
      ['users', () => rows('profiles', '*', { order: 'created_at', limit: 1000 })],
      ['wallets', () => rows('wallets', '*', { limit: 1000 })],
      ...(all || adminRole === 'task_manager' || adminRole === 'viewer' ? [['tasks', () => rpc('admin_task_list')]] : []),
      ...(all || adminRole === 'task_manager' ? [['submissions', () => rows('task_submissions', '*', { order: 'created_at', limit: 1000 })]] : []),
      ...(all || adminRole === 'finance' || adminRole === 'viewer' ? [['withdrawals', () => rows('withdrawals', '*', { order: 'created_at', limit: 1000 })]] : []),
      ...(all || adminRole === 'finance' || adminRole === 'viewer' ? [['transactions', () => rows('transactions', '*', { order: 'created_at', limit: 1000 })]] : []),
      ...(all ? [['promotions', () => rows('promotions', '*', { order: 'created_at', limit: 500 })], ['missions', () => rows('daily_missions', '*', { order: 'created_at', limit: 500 })], ['notifications', () => rows('notifications', '*', { order: 'created_at', limit: 500 })], ['audit', () => rows('user_activity_audit', '*', { order: 'created_at', limit: 500 })], ['settingsRows', () => rows('app_settings')]] : []),
    ];
    const failures = [];
    await Promise.all(jobs.map(async ([key, fn]) => {
      try {
        const value = await fn();
        if (key === 'settingsRows') for (const item of value) next.settings[item.key] = item.value;
        else next[key] = value;
      } catch (e) { failures.push(`${key}: ${friendlyError(e)}`); }
    }));
    setData(next);
    setLoading(false);
    await loadMetrics(false);
    if (failures.length) setMessage(`Some data could not be loaded: ${failures.join(' | ')}`);
  }

  async function login(email, password) {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setMessage(`Login failed: ${friendlyError(error)}`);
  }
  async function logout() { await supabase.auth.signOut(); setSession(null); setAdminRole(null); setSelectedUser(null); }
  async function rpc(name, params) { const { data: result, error } = await supabase.rpc(name, params); if (error) throw error; return result; }
  async function doAction(label, fn, options = {}) {
    setBusy(label);
    try { const result = await fn(); if (!options.skipReload) await loadAll(); setMessage(options.success || 'Action completed successfully.'); return result; }
    catch (e) { setMessage(`${label} failed: ${friendlyError(e)}`); throw e; }
    finally { setBusy(''); }
  }
  async function adjustBalance(user, amount, reason) {
    const value = Number(amount); if (!Number.isFinite(value) || value === 0) throw new Error('Enter a non-zero amount.');
    if (!reason.trim()) throw new Error('A reason is required.');
    await doAction('balance', () => rpc('admin_adjust_wallet', { p_user_id: user.id, p_amount: value, p_reason: reason.trim() }));
  }
  async function setUserStatus(user, status) {
    if (!window.confirm(`Set ${user.full_name || user.email || shortId(user.id)} to ${status}?`)) return;
    await doAction('status', () => rpc('admin_set_user_status', { p_user_id: user.id, p_status: status }));
  }
  async function sendNotification(userId, title, body, type = 'admin') {
    if (!title.trim() || !body.trim()) throw new Error('Title and message are required.');
    await doAction('notification', () => rpc('admin_send_notification', { p_user_id: userId || null, p_title: title.trim(), p_body: body.trim(), p_type: type, p_data: {} }));
  }
  async function saveSetting(key, value) { await doAction('settings', () => rpc('admin_set_app_setting', { p_key: key, p_value: value })); }
  async function saveSettings(values) {
    await doAction('settings', async () => {
      for (const [key, value] of Object.entries(values)) await rpc('admin_set_app_setting', { p_key: key, p_value: value });
    }, { success: 'All app controls saved.' });
  }

  const walletByUser = useMemo(() => Object.fromEntries(data.wallets.map((w) => [w.user_id, w])), [data.wallets]);
  const filteredUsers = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return data.users;
    return data.users.filter((u) => [u.full_name, u.email, u.phone, u.referral_code, u.id].some((v) => String(v || '').toLowerCase().includes(q)));
  }, [data.users, search]);
  const pendingSubmissions = data.submissions.filter((x) => x.status === 'pending');
  const pendingWithdrawals = data.withdrawals.filter((x) => x.status === 'pending' || x.status === 'processing');
  const totalBalance = data.wallets.reduce((s, x) => s + Number(x.balance || 0), 0);
  const totalEarned = data.wallets.reduce((s, x) => s + Number(x.total_earned || 0), 0);
  const totalWithdrawn = data.withdrawals.filter((x) => x.status === 'paid').reduce((s, x) => s + Number(x.amount || 0), 0);

  if (checking) return <div className="center-screen">Loading ZenexPay Admin…</div>;
  if (!session) return <Login onLogin={login} message={message} />;
  const common = { data, walletByUser, selectedUser, setSelectedUser, busy, doAction, rpc, loadAll, message, setMessage, adjustBalance, setUserStatus, sendNotification, saveSetting, saveSettings, session, adminRole };

  return <div className="app-shell">
    <Sidebar page={page} setPage={setPage} logout={logout} adminRole={adminRole} />
    <main className="main">
      <header className="topbar"><div><div className="eyebrow">ZENEXPAY CONTROL CENTER · {VERSION}</div><h1>{pageTitle(page)}</h1></div><div className="top-actions"><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search users…" /><button onClick={loadAll}>{loading ? 'Refreshing…' : 'Refresh'}</button><button className="ghost" onClick={logout}>Logout</button></div></header>
      {message && <div className="notice">{message}<button onClick={() => setMessage('')}>×</button></div>}
      {page === 'dashboard' && <Dashboard {...common} metrics={metrics} stats={{ users: data.users.length, tasks: data.tasks.length, submissions: data.submissions.length, withdrawals: data.withdrawals.length, pendingSubmissions: pendingSubmissions.length, pendingWithdrawals: pendingWithdrawals.length, totalBalance, totalEarned, totalWithdrawn }} setPage={setPage} />}
      {page === 'analytics' && <AnalyticsPage metrics={metrics} data={data} />}
      {page === 'users' && <UsersPage {...common} users={filteredUsers} />}
      {page === 'tasks' && <TasksPage {...common} readOnly={adminRole === 'viewer'} />}
      {page === 'submissions' && <SubmissionsPage {...common} />}
      {page === 'withdrawals' && <WithdrawalsPage {...common} readOnly={adminRole === 'viewer'} />}
      {page === 'transactions' && <TransactionsPage {...common} />}
      {page === 'promotions' && <PromotionsPage {...common} />}
      {page === 'missions' && <MissionsPage {...common} />}
      {page === 'notifications' && <NotificationsPage {...common} />}
      {page === 'support' && <SupportPage {...common} />}
      {page === 'settings' && <SettingsPage {...common} />}
      {page === 'audit' && <AuditPage {...common} />}
      {page === 'fraud' && <FraudPage {...common} />}
      {page === 'admins' && <AdminRolesPage {...common} />}
      {page === 'security' && <SecurityPage {...common} />}
      {page === 'reports' && <ReportsPage {...common} />}
      {page === 'health' && <HealthPage {...common} />}
    </main>
  </div>;
}

function pageTitle(page) { return ({ dashboard:'Dashboard',analytics:'Analytics',users:'Users',tasks:'Tasks',submissions:'Submissions',withdrawals:'Withdrawals',transactions:'Transactions',promotions:'Promotions',missions:'Daily Missions',notifications:'Notifications',support:'Support',settings:'App Control',audit:'Audit Logs',fraud:'Fraud & Risk',admins:'Admin Roles',security:'Admin Security',reports:'Reports & Export',health:'System Health' })[page] || 'Admin'; }
function Sidebar({ page, setPage, logout, adminRole }) {
  const all = adminRole === 'super_admin';
  const allowed = new Set(
    all ? ['dashboard','analytics','users','tasks','submissions','withdrawals','transactions','promotions','missions','notifications','support','settings','fraud','audit','admins','security','reports','health']
      : adminRole === 'finance' ? ['dashboard','analytics','users','withdrawals','transactions','reports']
      : adminRole === 'support' ? ['dashboard','analytics','users','support']
      : adminRole === 'task_manager' ? ['dashboard','analytics','users','tasks','submissions']
      : ['dashboard','analytics','users','tasks','withdrawals','transactions','reports']
  );
  const groups = [
    ['Core', [['dashboard','Dashboard'],['analytics','Analytics'],['users','Users'],['tasks','Tasks'],['submissions','Submissions'],['withdrawals','Withdrawals'],['transactions','Transactions']]],
    ['Growth', [['promotions','Promotions'],['missions','Daily Missions'],['notifications','Notifications'],['support','Support']]],
    ['Control', [['settings','App Control'],['fraud','Fraud & Risk'],['audit','Audit Logs'],['admins','Admin Roles'],['security','Admin Security'],['reports','Reports & Export'],['health','System Health']]],
  ];
  return <aside className="sidebar"><div className="brand"><div className="brand-mark">Z</div><div><b>Zenex<span>Pay</span></b><small>ADMIN CONTROL</small></div></div><div className="role-chip">{adminRole === 'super_admin' ? 'SUPER ADMIN' : String(adminRole || 'ADMIN').replace('_',' ').toUpperCase()}</div>{groups.map(([label,items])=><div className="nav-group" key={label}>{items.filter(([id])=>allowed.has(id)).map(([id,text])=><button key={id} className={page===id?'nav active':'nav'} onClick={()=>setPage(id)}>{text}</button>)}</div>)}<div className="sidebar-foot"><span>● System Online</span><small>30-minute inactive-session timeout</small><button onClick={logout}>Logout</button></div></aside>;
}

function Dashboard({ stats, metrics, data, setPage }) {
  const m = metrics || stats;
  return <div className="content"><section className="hero"><div><h2>Platform overview</h2><p>Real-time operational control across users, wallet, tasks, withdrawals and support.</p></div><div className="hero-actions"><button onClick={()=>setPage('withdrawals')}>Review withdrawals ({m.pending_withdrawals ?? stats.pendingWithdrawals})</button><button className="secondary" onClick={()=>setPage('submissions')}>Review submissions ({m.pending_submissions ?? stats.pendingSubmissions})</button></div></section>
    <div className="stats">{[['Users',m.users],['Active Users',m.active_users],['Tasks',m.tasks],['Submissions',m.submissions],['Pending Withdrawals',m.pending_withdrawals],['Live Balance',money(m.total_balance ?? stats.totalBalance)],['Total Earned',money(m.total_earned ?? stats.totalEarned)],['Total Withdrawn',money(m.total_withdrawn ?? stats.totalWithdrawn)]].map(([a,b])=><div className="stat" key={a}><small>{a}</small><strong>{b ?? 0}</strong></div>)}</div>
    <div className="grid-2"><Panel title="Today / 7-day activity"><div className="mini-stats"><Metric label="New users today" value={m.today_users ?? 0}/><Metric label="Submissions today" value={m.today_submissions ?? 0}/><Metric label="Withdrawn today" value={money(m.today_withdrawals)}/><Metric label="Earned today" value={money(m.today_earned)}/><Metric label="New users / 7d" value={m.week_users ?? 0}/><Metric label="Submissions / 7d" value={m.week_submissions ?? 0}/></div></Panel><Panel title="Operational alerts"><Alert label="Pending submissions" value={m.pending_submissions ?? stats.pendingSubmissions} action={()=>setPage('submissions')}/><Alert label="Pending / processing withdrawals" value={m.pending_withdrawals ?? stats.pendingWithdrawals} action={()=>setPage('withdrawals')}/><Alert label="Blocked users" value={m.blocked_users ?? data.users.filter(u=>u.status==='blocked').length} action={()=>setPage('users')}/></Panel></div>
    <Panel title="Recent audit activity">{data.audit.slice(0,10).map(a=><div className="row" key={a.id}><div><b>{a.action}</b><small>{shortId(a.user_id)} · {dateText(a.created_at)}</small></div><span>{a.entity_type}</span></div>)}{!data.audit.length&&<Empty text="No audit records yet."/>}</Panel>
  </div>;
}
function Metric({label,value}){return <div className="metric"><small>{label}</small><b>{value}</b></div>}
function Alert({label,value,action}){return <button className="alert" onClick={action}><span>{label}</span><b>{value}</b></button>}

function AnalyticsPage({metrics,data}){const m=metrics||{};return <div className="content"><section className="hero"><div><h2>Platform analytics</h2><p>Read-only operational analytics for active Admin roles.</p></div></section><div className="stats">{[['Users',m.users??data.users.length],['Active users',m.active_users??0],['Published tasks',m.published_tasks??0],['Submissions',m.submissions??data.submissions.length],['Pending submissions',m.pending_submissions??0],['Pending withdrawals',m.pending_withdrawals??0],['Live balance',money(m.total_balance??data.wallets.reduce((a,w)=>a+Number(w.balance||0),0))],['Total withdrawn',money(m.total_withdrawn??0)]].map(([a,b])=><div className="stat" key={a}><small>{a}</small><strong>{b}</strong></div>)}</div><div className="grid-2"><Panel title="Today"><div className="mini-stats"><Metric label="New users" value={m.today_users??0}/><Metric label="Submissions" value={m.today_submissions??0}/><Metric label="Withdrawals" value={money(m.today_withdrawals)}/><Metric label="Earned" value={money(m.today_earned)}/></div></Panel><Panel title="Last 7 days"><div className="mini-stats"><Metric label="New users" value={m.week_users??0}/><Metric label="Submissions" value={m.week_submissions??0}/><Metric label="Withdrawals" value={money(m.week_withdrawals)}/></div></Panel></div></div>}

function UsersPage({ users, walletByUser, selectedUser, setSelectedUser, ...rest }) { return <div className="content"><Panel title={`Users (${users.length})`}><div className="table-wrap"><table><thead><tr><th>User</th><th>Status</th><th>Balance</th><th>Earned</th><th>Joined</th><th/></tr></thead><tbody>{users.map(u=>{const w=walletByUser[u.id]||{};return <tr key={u.id}><td><b>{u.full_name||'Unnamed'}</b><small>{u.email||u.id}</small><small>{u.phone||''}</small></td><td><Badge value={u.status}/></td><td>{money(w.balance)}</td><td>{money(w.total_earned)}</td><td>{dateText(u.created_at)}</td><td><button className="small" onClick={()=>setSelectedUser(u)}>Manage</button></td></tr>})}</tbody></table></div></Panel>{selectedUser&&<UserDrawer user={selectedUser} wallet={walletByUser[selectedUser.id]} close={()=>setSelectedUser(null)} {...rest}/>}</div>; }

function UserDrawer({ user, wallet={}, close, adjustBalance, setUserStatus, sendNotification, busy, rpc, doAction, adminRole }) {
  const [amount,setAmount]=useState(''); const [reason,setReason]=useState(''); const [title,setTitle]=useState(''); const [body,setBody]=useState(''); const [snapshot,setSnapshot]=useState(null); const [loading,setLoading]=useState(false);
  useEffect(()=>{setLoading(true);rpc('admin_user_snapshot',{p_user_id:user.id}).then(setSnapshot).catch(()=>setSnapshot(null)).finally(()=>setLoading(false));},[user.id]);
  const tx=snapshot?.transactions||[]; const subs=snapshot?.submissions||[]; const wd=snapshot?.withdrawals||[]; const canFinance=adminRole==='super_admin'||adminRole==='finance'; const canControl=adminRole==='super_admin'; const canNotify=adminRole==='super_admin'||adminRole==='support';
  return <div className="drawer-backdrop" onClick={close}><aside className="drawer" onClick={e=>e.stopPropagation()}><div className="drawer-head"><div><h2>{user.full_name||'User'}</h2><small>{user.email||user.id}</small></div><button onClick={close}>×</button></div><div className="profile-grid"><div><small>UID</small><b>{user.id}</b></div><div><small>Status</small><Badge value={user.status}/></div><div><small>Balance</small><b>{money(wallet.balance)}</b></div><div><small>Total earned</small><b>{money(wallet.total_earned)}</b></div><div><small>Total withdrawn</small><b>{money(snapshot?.total_withdrawn ?? 0)}</b></div><div><small>Referral</small><b>{user.referral_code||'-'}</b></div><div><small>Referrals</small><b>{snapshot?.referrals??'—'}</b></div><div><small>Referral earnings</small><b>{money(snapshot?.referral_earnings)}</b></div></div>
    {canFinance&&<Panel title="Wallet adjustment"><input placeholder="Amount (+ add / - deduct)" value={amount} onChange={e=>setAmount(e.target.value)}/><input placeholder="Reason (required)" value={reason} onChange={e=>setReason(e.target.value)}/><button disabled={!!busy} onClick={()=>adjustBalance(user,amount,reason)}>Apply balance adjustment</button></Panel>}
    {canControl&&<Panel title="Account control"><div className="button-row">{user.status==='blocked'?<button onClick={()=>setUserStatus(user,'active')}>Unblock user</button>:<button className="danger" onClick={()=>setUserStatus(user,'blocked')}>Block user</button>}</div></Panel>}
    {canNotify&&<Panel title="Send notification"><input placeholder="Title" value={title} onChange={e=>setTitle(e.target.value)}/><textarea placeholder="Message" value={body} onChange={e=>setBody(e.target.value)}/><button onClick={()=>sendNotification(user.id,title,body)}>Send notification</button></Panel>}
    <Panel title={`Recent withdrawals (${wd.length})`}>{loading?<Empty text="Loading snapshot…"/>:wd.slice(0,8).map(x=><div className="row" key={x.id}><div><b>{money(x.amount)} · {x.method}</b><small>{x.status} · {dateText(x.created_at)}</small></div><span>{maskAccount(x.account_number)}</span></div>)}</Panel>
    <Panel title={`Recent submissions (${subs.length})`}>{subs.slice(0,8).map(x=><div className="row" key={x.id}><div><b>{shortId(x.task_id)}</b><small>{x.status} · {dateText(x.created_at)}</small></div></div>)}</Panel>
    <Panel title={`Recent transactions (${tx.length})`}>{tx.slice(0,10).map(x=><div className="row" key={x.id}><div><b>{x.type}</b><small>{x.description||'-'} · {dateText(x.created_at)}</small></div><span>{money(x.amount)}</span></div>)}</Panel>
  </aside></div>;
}

function TasksPage({data,doAction,rpc,busy,readOnly=false}){
  const empty={title:'',description:'',instructions:'',reward:'',max:'',proof:true}; const [form,setForm]=useState(empty); const [editing,setEditing]=useState(null);
  const save=async()=>{if(!form.title.trim()||Number(form.reward)<=0)throw new Error('Title and positive reward are required.');if(editing)await doAction('task update',()=>rpc('admin_update_task',{p_task_id:editing.id,p_title:form.title.trim(),p_description:form.description.trim(),p_instructions:form.instructions.trim(),p_reward:Number(form.reward),p_max_submissions:form.max?Number(form.max):null,p_proof_required:form.proof}));else await doAction('task',()=>rpc('admin_create_task',{p_title:form.title.trim(),p_description:form.description.trim(),p_instructions:form.instructions.trim(),p_reward:Number(form.reward),p_max_submissions:form.max?Number(form.max):null,p_proof_required:form.proof}));setForm(empty);setEditing(null)};
  const edit=t=>{setEditing(t);setForm({title:t.title,description:t.description||'',instructions:t.instructions||'',reward:t.reward,max:t.max_submissions||'',proof:t.proof_required});window.scrollTo({top:0,behavior:'smooth'})};
  return <div className="content">{!readOnly && <Panel title={editing?`Edit task · ${shortId(editing.id)}`:'Create task'}><div className="form-grid"><input placeholder="Title" value={form.title} onChange={e=>setForm({...form,title:e.target.value})}/><input placeholder="Reward" type="number" value={form.reward} onChange={e=>setForm({...form,reward:e.target.value})}/><input placeholder="Max submissions (optional)" type="number" value={form.max} onChange={e=>setForm({...form,max:e.target.value})}/></div><label className="toggle"><input type="checkbox" checked={form.proof} onChange={e=>setForm({...form,proof:e.target.checked})}/> Proof required</label><textarea placeholder="Description" value={form.description} onChange={e=>setForm({...form,description:e.target.value})}/><textarea placeholder="Instructions" value={form.instructions} onChange={e=>setForm({...form,instructions:e.target.value})}/><div className="button-row"><button disabled={!!busy} onClick={save}>{editing?'Save task changes':'Create & publish task'}</button>{editing&&<button className="secondary" onClick={()=>{setEditing(null);setForm(empty)}}>Cancel edit</button>}</div></Panel>}{readOnly && <Panel title="Viewer access"><p className="muted">Viewer is read-only. Task creation, editing, publishing, pausing and closing are disabled.</p></Panel>}<Panel title={`Tasks (${data.tasks.length})`}><div className="table-wrap"><table><thead><tr><th>Task</th><th>Reward</th><th>Submissions</th><th>Status</th><th>Created</th><th>Actions</th></tr></thead><tbody>{data.tasks.map(t=><tr key={t.id}><td><b>{t.title}</b><small>{t.description}</small></td><td>{money(t.reward)}</td><td>{t.current_submissions||0}{t.max_submissions?` / ${t.max_submissions}`:''}</td><td><Badge value={t.status}/></td><td>{dateText(t.created_at)}</td><td>{readOnly ? <span className="muted">Read-only</span> : <div className="button-row"><button className="small" onClick={()=>edit(t)}>Edit</button><button className="small" onClick={()=>doAction('task status',()=>rpc('admin_set_task_status',{p_task_id:t.id,p_status:t.status==='published'?'paused':'published'}))}>{t.status==='published'?'Pause':'Publish'}</button><button className="small danger" onClick={()=>doAction('task close',()=>rpc('admin_set_task_status',{p_task_id:t.id,p_status:'closed'}))}>Close</button></div>}</td></tr>)}</tbody></table></div></Panel></div>;
}

async function openTaskScreenshot(path) {
  if (!path) return;
  const { data, error } = await supabase.storage.from('task-submissions').createSignedUrl(path, 3600);
  if (error) { setTimeout(() => window.alert(error.message || 'Could not open screenshot.'), 0); return; }
  if (data?.signedUrl) window.open(data.signedUrl, '_blank', 'noopener,noreferrer');
}

function SubmissionsPage({data,rpc,doAction}){return <div className="content"><Panel title={`Submissions (${data.submissions.length})`}><div className="table-wrap"><table><thead><tr><th>Submission</th><th>Task</th><th>User</th><th>Proof</th><th>Status</th><th>Created</th><th/></tr></thead><tbody>{data.submissions.map(s=><tr key={s.id}><td>{shortId(s.id)}</td><td>{shortId(s.task_id)}</td><td>{shortId(s.user_id)}</td><td><div>{s.proof_text||'-'}</div>{s.screenshot_path&&<button className="link-btn" onClick={()=>openTaskScreenshot(s.screenshot_path)}>Open screenshot</button>}</td><td><Badge value={s.status}/></td><td>{dateText(s.created_at)}</td><td>{(s.status==='pending'||s.status==='screenshot_submitted')&&<div className="button-row"><button className="small" onClick={()=>doAction('approve',()=>rpc('admin_approve_submission',{p_submission_id:s.id}))}>Approve</button><button className="small danger" onClick={()=>{const note=window.prompt('Rejection reason:')||'';if(note.trim())return doAction('reject',()=>rpc('admin_reject_submission',{p_submission_id:s.id,p_reason:note}))}}>Reject</button></div>}</td></tr>)}</tbody></table></div></Panel></div>}

function WithdrawalsPage({data,rpc,doAction,readOnly=false}){const [revealed,setRevealed]=useState({});const act=async(w,status)=>{if(status==='paid'&&!window.confirm(`Confirm that ${money(w.amount)} was actually sent to ${w.method} account ending ${String(w.account_number||'').slice(-4)}?`))return;const note=window.prompt(status==='rejected'?'Rejection reason:':status==='paid'?'Payment note (optional):':'Processing note (optional):')??'';if(status==='rejected'&&!note.trim())return;await doAction(`withdrawal ${status}`,()=>rpc('admin_process_withdrawal',{p_withdrawal_id:w.id,p_status:status,p_note:note.trim()||null}))};return <div className="content"><Panel title={`Withdrawals (${data.withdrawals.length})`}><div className="table-wrap"><table><thead><tr><th>User</th><th>Amount</th><th>Method</th><th>Account</th><th>Status</th><th>Created</th><th/></tr></thead><tbody>{data.withdrawals.map(w=><tr key={w.id}><td>{shortId(w.user_id)}</td><td>{money(w.amount)}</td><td>{w.method}</td><td>{revealed[w.id]?w.account_number:maskAccount(w.account_number)} <button className="link-btn" onClick={()=>setRevealed(x=>({...x,[w.id]:!x[w.id]}))}>{revealed[w.id]?'Hide':'Reveal'}</button></td><td><Badge value={w.status}/></td><td>{dateText(w.created_at)}</td><td>{readOnly ? <span className="muted">Read-only</span> : (w.status==='pending'||w.status==='processing')&&<div className="button-row">{w.status==='pending'&&<button className="small" onClick={()=>act(w,'processing')}>Process</button>}<button className="small" onClick={()=>act(w,'paid')}>Paid</button><button className="small danger" onClick={()=>act(w,'rejected')}>Reject</button></div>}</td></tr>)}</tbody></table></div></Panel></div>}
function TransactionsPage({data}){return <div className="content"><Panel title={`Transactions (${data.transactions.length})`}><div className="table-wrap"><table><thead><tr><th>User</th><th>Type</th><th>Amount</th><th>Status</th><th>Description</th><th>Date</th></tr></thead><tbody>{data.transactions.map(t=><tr key={t.id}><td>{shortId(t.user_id)}</td><td><Badge value={t.type}/></td><td>{money(t.amount)}</td><td>{t.status||'-'}</td><td>{t.description||'-'}</td><td>{dateText(t.created_at)}</td></tr>)}</tbody></table></div></Panel></div>}

function PromotionsPage({data,rpc,doAction}){const blank={title:'',description:'',reward:0,kind:'bonus',starts:'',ends:'',active:true};const [f,setF]=useState(blank);const [editing,setEditing]=useState(null);const save=()=>doAction('promotion',()=>editing?rpc('admin_update_promotion',{p_promotion_id:editing.id,p_title:f.title,p_description:f.description,p_reward:Number(f.reward),p_kind:f.kind,p_starts_at:f.starts||null,p_ends_at:f.ends||null,p_is_active:f.active}):rpc('admin_create_promotion',{p_title:f.title,p_description:f.description,p_reward:Number(f.reward),p_kind:f.kind,p_starts_at:f.starts||new Date().toISOString(),p_ends_at:f.ends||null})).then(()=>{setF(blank);setEditing(null)});return <div className="content"><Panel title={editing?'Edit promotion':'Create promotion'}><div className="form-grid"><input placeholder="Title" value={f.title} onChange={e=>setF({...f,title:e.target.value})}/><input placeholder="Reward" type="number" value={f.reward} onChange={e=>setF({...f,reward:e.target.value})}/><select value={f.kind} onChange={e=>setF({...f,kind:e.target.value})}><option value="bonus">bonus</option><option value="campaign">campaign</option><option value="reward">reward</option><option value="info">info</option></select></div><textarea placeholder="Description" value={f.description} onChange={e=>setF({...f,description:e.target.value})}/><div className="form-grid"><input type="datetime-local" value={f.starts} onChange={e=>setF({...f,starts:e.target.value})}/><input type="datetime-local" value={f.ends} onChange={e=>setF({...f,ends:e.target.value})}/><label className="toggle"><input type="checkbox" checked={f.active} onChange={e=>setF({...f,active:e.target.checked})}/> Active</label></div><div className="button-row"><button onClick={save}>{editing?'Save changes':'Create promotion'}</button>{editing&&<button className="secondary" onClick={()=>{setEditing(null);setF(blank)}}>Cancel</button>}</div></Panel><Panel title="Existing promotions"><div className="table-wrap"><table><thead><tr><th>Title</th><th>Reward</th><th>Active</th><th>Dates</th><th/></tr></thead><tbody>{data.promotions.map(p=><tr key={p.id}><td>{p.title}</td><td>{money(p.reward)}</td><td><Badge value={p.is_active?'active':'inactive'}/></td><td>{dateText(p.starts_at)} → {dateText(p.ends_at)}</td><td><div className="button-row"><button className="small" onClick={()=>{setEditing(p);setF({title:p.title,description:p.description||'',reward:p.reward,kind:p.kind||'bonus',starts:p.starts_at?new Date(p.starts_at).toISOString().slice(0,16):'',ends:p.ends_at?new Date(p.ends_at).toISOString().slice(0,16):'',active:p.is_active})}}>Edit</button><button className="small" onClick={()=>doAction('promotion status',()=>rpc('admin_set_promotion_status',{p_promotion_id:p.id,p_is_active:!p.is_active}))}>{p.is_active?'Disable':'Enable'}</button></div></td></tr>)}</tbody></table></div></Panel></div>}

function MissionsPage({data,rpc,doAction}){const blank={title:'',description:'',reward:0,target:1,active:true};const [f,setF]=useState(blank);const [editing,setEditing]=useState(null);const save=()=>doAction('mission',()=>editing?rpc('admin_update_daily_mission',{p_mission_id:editing.id,p_title:f.title,p_description:f.description,p_reward:Number(f.reward),p_target_tasks:Number(f.target),p_is_active:f.active}):rpc('admin_create_daily_mission',{p_title:f.title,p_description:f.description,p_reward:Number(f.reward),p_target_tasks:Number(f.target)})).then(()=>{setF(blank);setEditing(null)});return <div className="content"><Panel title={editing?'Edit daily mission':'Create daily mission'}><div className="form-grid"><input placeholder="Title" value={f.title} onChange={e=>setF({...f,title:e.target.value})}/><input placeholder="Reward" type="number" value={f.reward} onChange={e=>setF({...f,reward:e.target.value})}/><input placeholder="Target tasks" type="number" value={f.target} onChange={e=>setF({...f,target:e.target.value})}/></div><textarea placeholder="Description" value={f.description} onChange={e=>setF({...f,description:e.target.value})}/><label className="toggle"><input type="checkbox" checked={f.active} onChange={e=>setF({...f,active:e.target.checked})}/> Active</label><div className="button-row"><button onClick={save}>{editing?'Save changes':'Create mission'}</button>{editing&&<button className="secondary" onClick={()=>{setEditing(null);setF(blank)}}>Cancel</button>}</div></Panel><Panel title="Missions"><div className="table-wrap"><table><thead><tr><th>Title</th><th>Reward</th><th>Target</th><th>Active</th><th/></tr></thead><tbody>{data.missions.map(m=><tr key={m.id}><td>{m.title}</td><td>{money(m.reward)}</td><td>{m.target_tasks}</td><td><Badge value={m.is_active?'active':'inactive'}/></td><td><div className="button-row"><button className="small" onClick={()=>{setEditing(m);setF({title:m.title,description:m.description||'',reward:m.reward,target:m.target_tasks,active:m.is_active})}}>Edit</button><button className="small" onClick={()=>doAction('mission status',()=>rpc('admin_set_daily_mission_status',{p_mission_id:m.id,p_is_active:!m.is_active}))}>{m.is_active?'Disable':'Enable'}</button></div></td></tr>)}</tbody></table></div></Panel></div>}

function NotificationsPage({data,sendNotification}){const [user,setUser]=useState('');const [title,setTitle]=useState('');const [body,setBody]=useState('');return <div className="content"><Panel title="Send notification"><p className="muted">Leave User ID empty to broadcast to all active profiles. Use a specific UUID for a single user.</p><input placeholder="User UUID (optional)" value={user} onChange={e=>setUser(e.target.value)}/><input placeholder="Title" value={title} onChange={e=>setTitle(e.target.value)}/><textarea placeholder="Message" value={body} onChange={e=>setBody(e.target.value)}/><button onClick={()=>sendNotification(user.trim()||null,title,body)}>Send notification</button></Panel><Panel title="Recent notifications"><div className="table-wrap"><table><thead><tr><th>User</th><th>Title</th><th>Message</th><th>Read</th><th>Date</th></tr></thead><tbody>{data.notifications.slice(0,200).map(n=><tr key={n.id}><td>{shortId(n.user_id)}</td><td>{n.title}</td><td>{n.body}</td><td>{n.is_read?'Yes':'No'}</td><td>{dateText(n.created_at)}</td></tr>)}</tbody></table></div></Panel></div>}

function SupportPage({rpc,doAction}){
  const [conversations,setConversations]=useState([]); const [selected,setSelected]=useState(null); const [messages,setMessages]=useState([]); const [userHistory,setUserHistory]=useState(null); const [message,setMessage]=useState(''); const [loading,setLoading]=useState(false);
  const load=async()=>{try{setConversations(await rpc('admin_support_conversations')||[])}catch(e){setConversations([])}};
  const loadMessages=async(id)=>{try{const r=await supabase.from('support_messages').select('id,conversation_id,sender_id,sender_type,message,is_read,created_at').eq('conversation_id',id).order('created_at',{ascending:true}); if(r.error)throw r.error; setMessages(r.data||[])}catch(_){setMessages([])}};
  useEffect(()=>{load(); const ch=supabase.channel('zenexpay-support-admin').on('postgres_changes',{event:'*',schema:'public',table:'support_conversations'},()=>load()).subscribe(); return ()=>{supabase.removeChannel(ch)}},[]);
  const select=async(c)=>{setSelected(c);setUserHistory(null);await loadMessages(c.conversation_id);try{setUserHistory(await rpc('admin_user_snapshot',{p_user_id:c.user_id}))}catch(_){setUserHistory(null)}};
  const send=async()=>{if(!selected||!message.trim())return; await doAction('support reply',()=>rpc('admin_send_support_message',{p_conversation_id:selected.conversation_id,p_message:message.trim()}));setMessage('');await loadMessages(selected.conversation_id);await load()};
  const close=async()=>{if(!selected)return; if(!window.confirm('Close this support conversation?'))return; await doAction('support close',()=>rpc('admin_close_support_conversation',{p_conversation_id:selected.conversation_id}));setSelected({...selected,status:'resolved'});await load()};
  return <div className="content"><section className="split-support"><Panel title={`Human support queue (${conversations.filter(c=>c.status==='human_requested'||c.status==='human_active').length})`}><div className="support-list">{!conversations.length&&<Empty text="No support conversations yet."/>}{conversations.map(c=><button key={c.conversation_id} className={`support-item ${selected?.conversation_id===c.conversation_id?'selected':''}`} onClick={()=>select(c)}><div><b>{c.full_name||'User'}</b><small>{c.email||shortId(c.user_id)}</small></div><div><Badge value={c.status}/><small>{dateText(c.updated_at)}</small></div></button>)}</div></Panel><Panel title={selected?`Conversation · ${selected.full_name||shortId(selected.user_id)}`:'Select a conversation'}>{!selected?<Empty text="Select a support conversation from the queue."/>:<><div className="conversation-meta"><Badge value={selected.status}/><span>{selected.email||shortId(selected.user_id)}</span></div>{userHistory&&<div className="user-history"><b>User history</b><span>Balance {money(userHistory.wallet?.balance)}</span><span>Earned {money(userHistory.wallet?.total_earned)}</span><span>Withdrawals {userHistory.withdrawals?.length||0}</span><span>Submissions {userHistory.submissions?.length||0}</span>{(userHistory.transactions||[]).slice(0,4).map(t=><span key={t.id}>{t.type}: {money(t.amount)}</span>)}</div>}<div className="chat-history">{messages.map(m=><div key={m.id} className={`chat-bubble ${m.sender_type||'user'}`}><small>{m.sender_type}</small><div>{m.message}</div><time>{dateText(m.created_at)}</time></div>)}</div>{selected.status!=='resolved'&&<><textarea placeholder="Reply to user" value={message} onChange={e=>setMessage(e.target.value)}/><div className="button-row"><button onClick={send} disabled={!message.trim()}>Reply</button><button className="danger" onClick={close}>Close conversation</button></div></>}</>}</Panel></section></div>;
}

function SettingsPage({data,saveSettings}){
  const current=(key,fallback)=>data.settings[key]??fallback;
  const [maintenance,setMaintenance]=useState(Boolean(current('maintenance_mode',false))); const [msg,setMsg]=useState(current('maintenance_message','System maintenance is in progress. Please try again later.')); const [minV,setMinV]=useState(current('minimum_app_version','1.0.0')); const [latest,setLatest]=useState(current('latest_app_version','1.0.0')); const [force,setForce]=useState(Boolean(current('force_update',false))); const [minW,setMinW]=useState(current('minimum_withdrawal',{amount:100}).amount??100); const [maxW,setMaxW]=useState(current('maximum_withdrawal',{amount:50000}).amount??50000); const [dailyW,setDailyW]=useState(current('daily_withdrawal_limit',{amount:100000}).amount??100000); const [withdrawals,setWithdrawals]=useState(current('withdrawals_enabled',true)!==false); const [reg,setReg]=useState(current('new_registrations_enabled',true)!==false); const [tasks,setTasks]=useState(current('task_system_enabled',true)!==false); const [checkin,setCheckin]=useState(current('daily_checkin_enabled',true)!==false); const [missions,setMissions]=useState(current('daily_missions_enabled',true)!==false); const [referral,setReferral]=useState(current('referral_system_enabled',true)!==false); const [support,setSupport]=useState(current('support_enabled',true)!==false);
  const save=async()=>saveSettings({maintenance_mode:maintenance,maintenance_message:msg,minimum_app_version:minV,latest_app_version:latest,force_update:force,minimum_withdrawal:{amount:Number(minW)},maximum_withdrawal:{amount:Number(maxW)},daily_withdrawal_limit:{amount:Number(dailyW)},withdrawals_enabled:withdrawals,new_registrations_enabled:reg,task_system_enabled:tasks,daily_checkin_enabled:checkin,daily_missions_enabled:missions,referral_system_enabled:referral,support_enabled:support});
  return <div className="content"><Panel title="App availability & updates"><label className="toggle"><input type="checkbox" checked={maintenance} onChange={e=>setMaintenance(e.target.checked)}/> Maintenance mode</label><textarea value={msg} onChange={e=>setMsg(e.target.value)}/><div className="form-grid"><input placeholder="Minimum app version" value={minV} onChange={e=>setMinV(e.target.value)}/><input placeholder="Latest app version" value={latest} onChange={e=>setLatest(e.target.value)}/><label className="toggle"><input type="checkbox" checked={force} onChange={e=>setForce(e.target.checked)}/> Force update</label></div></Panel><Panel title="Wallet & withdrawal rules"><div className="form-grid"><label>Minimum<input type="number" value={minW} onChange={e=>setMinW(e.target.value)}/></label><label>Maximum<input type="number" value={maxW} onChange={e=>setMaxW(e.target.value)}/></label><label>Daily limit<input type="number" value={dailyW} onChange={e=>setDailyW(e.target.value)}/></label></div><label className="toggle"><input type="checkbox" checked={withdrawals} onChange={e=>setWithdrawals(e.target.checked)}/> Withdrawals enabled</label></Panel><Panel title="Feature switches"><div className="feature-grid"><Toggle label="New registrations" value={reg} setValue={setReg}/><Toggle label="Task system" value={tasks} setValue={setTasks}/><Toggle label="Daily check-in" value={checkin} setValue={setCheckin}/><Toggle label="Daily missions" value={missions} setValue={setMissions}/><Toggle label="Referral system" value={referral} setValue={setReferral}/><Toggle label="Support" value={support} setValue={setSupport}/></div></Panel><button onClick={save}>Save all app controls</button></div>;
}
function Toggle({label,value,setValue}){return <label className="toggle card-toggle"><input type="checkbox" checked={value} onChange={e=>setValue(e.target.checked)}/>{label}</label>}

function AuditPage({data}){const [q,setQ]=useState('');const [action,setAction]=useState('');const list=data.audit.filter(a=>(!q||JSON.stringify(a).toLowerCase().includes(q.toLowerCase()))&&(!action||a.action===action));const actions=[...new Set(data.audit.map(a=>a.action).filter(Boolean))].sort();return <div className="content"><Panel title="Audit log"><div className="form-grid"><input placeholder="Search audit details" value={q} onChange={e=>setQ(e.target.value)}/><select value={action} onChange={e=>setAction(e.target.value)}><option value="">All actions</option>{actions.map(a=><option key={a}>{a}</option>)}</select></div><div className="table-wrap"><table><thead><tr><th>Time</th><th>Action</th><th>User</th><th>Actor</th><th>Entity</th><th>Details</th></tr></thead><tbody>{list.map(a=><tr key={a.id}><td>{dateText(a.created_at)}</td><td>{a.action}</td><td>{shortId(a.user_id)}</td><td>{shortId(a.actor_id)}</td><td>{a.entity_type} / {shortId(a.entity_id)}</td><td><code>{JSON.stringify(a.metadata||{})}</code></td></tr>)}</tbody></table></div></Panel></div>}

function FraudPage({rpc,setSelectedUser}){const [items,setItems]=useState([]);const [loading,setLoading]=useState(false);const load=async()=>{setLoading(true);try{setItems(await rpc('admin_fraud_flags')||[])}catch(e){setItems([])}finally{setLoading(false)}};useEffect(()=>{load()},[]);return <div className="content"><section className="hero"><div><h2>Fraud & risk signals</h2><p>Heuristics only—these are review flags, not automatic proof of abuse.</p></div><button onClick={load}>{loading?'Scanning…':'Run scan'}</button></section><Panel title={`Flags (${items.length})`}>{!items.length?<Empty text="No current flags found."/>:<div className="table-wrap"><table><thead><tr><th>Severity</th><th>User</th><th>Flag</th><th>Detail</th><th>Detected</th></tr></thead><tbody>{items.map((x,i)=><tr key={`${x.user_id}-${x.flag}-${i}`}><td><Badge value={x.severity}/></td><td><button className="link-btn" onClick={()=>setSelectedUser({id:x.user_id})}>{shortId(x.user_id)}</button></td><td>{x.flag}</td><td>{x.detail}</td><td>{dateText(x.detected_at)}</td></tr>)}</tbody></table></div>}</Panel></div>}

function AdminRolesPage({rpc,doAction}){
  const [roles,setRoles]=useState([]); const [matches,setMatches]=useState([]); const [query,setQuery]=useState('');
  const [user,setUser]=useState(''); const [role,setRole]=useState('viewer'); const [note,setNote]=useState(''); const [active,setActive]=useState(true);
  const load=async()=>{try{setRoles(await rpc('admin_list_roles')||[])}catch(_){setRoles([])}}; useEffect(()=>{load()},[]);
  const find=async()=>{try{setMatches(await rpc('admin_find_users',{p_query:query.trim()})||[])}catch(e){setMatches([])}};
  const save=async()=>{if(!user.trim())throw new Error('Select or enter a user UUID.'); await doAction('admin role',()=>rpc('admin_set_role',{p_user_id:user.trim(),p_role:role,p_note:note.trim(),p_is_active:active})); setUser('');setQuery('');setRole('viewer');setNote('');setActive(true);setMatches([]);await load()};
  const toggle=async(r)=>{ await doAction('admin status',()=>rpc('admin_set_role',{p_user_id:r.user_id,p_role:r.role,p_note:r.note||'',p_is_active:!r.is_active})); await load()};
  const remove=async(r)=>{if(!window.confirm(`Remove admin role for ${r.email||r.user_id}?`))return; await doAction('admin remove',()=>rpc('admin_set_role',{p_user_id:r.user_id,p_role:'none',p_note:'Removed by Super Admin',p_is_active:false})); await load()};
  return <div className="content">
    <Panel title="Create / manage admin access"><p className="muted">Select an existing ZenexPay user and grant an Admin role. Authentication accounts remain managed by Supabase Auth; this page controls their server-side Admin access.</p><div className="form-grid"><input placeholder="Search name, email or UUID" value={query} onChange={e=>setQuery(e.target.value)} /><button className="secondary" onClick={find}>Find user</button></div>{matches.length>0&&<div className="search-results">{matches.map(m=><button key={m.user_id} className="search-result" onClick={()=>{setUser(m.user_id);setQuery(m.email||m.full_name||m.user_id);setMatches([])}}><b>{m.full_name||'Unnamed'}</b><small>{m.email||m.user_id} · {m.status}</small></button>)}</div>}<input placeholder="Selected User UUID" value={user} onChange={e=>setUser(e.target.value)}/><div className="form-grid"><select value={role} onChange={e=>setRole(e.target.value)}><option value="viewer">Viewer</option><option value="support">Support Admin</option><option value="finance">Finance Admin</option><option value="task_manager">Task Manager</option><option value="super_admin">Super Admin</option></select><input placeholder="Note" value={note} onChange={e=>setNote(e.target.value)}/></div><label className="toggle"><input type="checkbox" checked={active} onChange={e=>setActive(e.target.checked)}/> Active</label><button onClick={save}>Save Admin Access</button></Panel>
    <Panel title="Permission model"><div className="table-wrap"><table><thead><tr><th>Role</th><th>Users</th><th>Wallet/Finance</th><th>Tasks</th><th>Support</th><th>App Control</th></tr></thead><tbody><tr><td><b>Super Admin</b></td><td>Full</td><td>Full</td><td>Full</td><td>Full</td><td>Full</td></tr><tr><td>Finance Admin</td><td>Read</td><td>Full</td><td>Read</td><td>—</td><td>—</td></tr><tr><td>Support Admin</td><td>Read</td><td>—</td><td>—</td><td>Full</td><td>—</td></tr><tr><td>Task Manager</td><td>Read</td><td>—</td><td>Full</td><td>—</td><td>—</td></tr><tr><td>Viewer</td><td>Read</td><td>Read</td><td>Read</td><td>—</td><td>—</td></tr></tbody></table></div></Panel>
    <Panel title={`Current admins (${roles.length})`}><div className="table-wrap"><table><thead><tr><th>User</th><th>Email</th><th>Role</th><th>Status</th><th>Note</th><th>Updated</th><th/></tr></thead><tbody>{roles.map(r=><tr key={r.user_id}><td><b>{r.full_name||'Unnamed'}</b><small>{shortId(r.user_id)}</small></td><td>{r.email||'-'}</td><td><Badge value={r.role}/></td><td><Badge value={r.is_active?'active':'inactive'}/></td><td>{r.note||'-'}</td><td>{dateText(r.updated_at||r.created_at)}</td><td><div className="button-row"><button className="small" disabled={r.is_root} onClick={()=>toggle(r)}>{r.is_root?'Root Admin':r.is_active?'Deactivate':'Activate'}</button>{!r.is_root&&<button className="small danger" onClick={()=>remove(r)}>Remove</button>}</div></td></tr>)}</tbody></table></div></Panel>
  </div>;
}

function SecurityPage(){const [factors,setFactors]=useState([]);const [loading,setLoading]=useState(false);const [secret,setSecret]=useState('');const [factorId,setFactorId]=useState('');const [code,setCode]=useState('');const [message,setMessage]=useState('');const load=async()=>{try{const r=await supabase.auth.mfa.listFactors();setFactors(r.data?.totp||[])}catch(e){setMessage(friendlyError(e))}};useEffect(()=>{load()},[]);const enroll=async()=>{setLoading(true);try{const r=await supabase.auth.mfa.enroll({factorType:'totp',friendlyName:'ZenexPay Admin'});setFactorId(r.data.id);setSecret(r.data.totp?.secret||'');setMessage('Scan the QR shown by Supabase Auth UI if your deployment exposes it, or use the secret with an authenticator app. Then verify the 6-digit code.')}catch(e){setMessage(friendlyError(e))}finally{setLoading(false)}};const verify=async()=>{setLoading(true);try{const c=await supabase.auth.mfa.challenge({factorId});const v=await supabase.auth.mfa.verify({factorId,challengeId:c.data.id,code});if(v.error)throw v.error;setMessage('MFA verified successfully.');setSecret('');setCode('');await load()}catch(e){setMessage(friendlyError(e))}finally{setLoading(false)}};return <div className="content"><Panel title="Two-factor authentication"><p className="muted">MFA is optional until you verify it. This upgrade does not lock existing admins out automatically.</p>{message&&<div className="notice">{message}</div>}<p>Registered TOTP factors: <b>{factors.length}</b></p>{!factors.length&&<button onClick={enroll} disabled={loading}>Enable TOTP MFA</button>}{secret&&<div className="mfa-box"><b>Secret</b><code>{secret}</code><input inputMode="numeric" maxLength="6" placeholder="6-digit authenticator code" value={code} onChange={e=>setCode(e.target.value)}/><button onClick={verify} disabled={loading||!factorId||code.length<6}>Verify MFA</button></div>}</Panel><Panel title="Session security"><div className="mini-stats"><Metric label="Idle timeout" value="30 minutes"/><Metric label="Privileged writes" value="Server-side RPC"/><Metric label="Realtime" value="Enabled"/></div></Panel></div>}

function Panel({title,children}){return <section className="panel"><div className="panel-title"><h3>{title}</h3></div>{children}</section>}
function Badge({value}){return <span className={`badge ${String(value||'').toLowerCase()}`}>{value||'-'}</span>}
function Empty({text}){return <div className="empty">{text}</div>}

function downloadCsv(filename, rows) {
  if (!rows.length) return;
  const keys=[...new Set(rows.flatMap(r=>Object.keys(r)))];
  const esc=v=>`"${String(v??'').replaceAll('"','""')}"`;
  const csv=[keys.map(esc).join(','),...rows.map(r=>keys.map(k=>esc(typeof r[k]==='object'&&r[k]!==null?JSON.stringify(r[k]):r[k])).join(','))].join('\n');
  const blob=new Blob([csv],{type:'text/csv;charset=utf-8'}); const url=URL.createObjectURL(blob);
  const a=document.createElement('a'); a.href=url; a.download=filename; a.click(); URL.revokeObjectURL(url);
}

function ReportsPage({rpc,data}){
  const [rows,setRows]=useState([]); const [loading,setLoading]=useState(false); const [days,setDays]=useState(30);
  const load=async()=>{setLoading(true);try{const to=new Date().toISOString();const from=new Date(Date.now()-Number(days)*86400000).toISOString();setRows(await rpc('admin_financial_report',{p_from:from,p_to:to})||[])}catch(e){setRows([])}finally{setLoading(false)}};
  useEffect(()=>{load()},[days]);
  return <div className="content"><section className="hero"><div><h2>Financial reports</h2><p>Server-side aggregates for finance review. No payment account numbers are exported here.</p></div><div className="hero-actions"><select value={days} onChange={e=>setDays(e.target.value)}><option value="7">7 days</option><option value="30">30 days</option><option value="90">90 days</option></select><button onClick={load}>{loading?'Loading…':'Refresh'}</button><button className="secondary" onClick={()=>downloadCsv(`zenexpay-financial-${days}d.csv`,rows)}>Export CSV</button></div></section><Panel title={`Daily financial report (${rows.length} days)`}><div className="table-wrap"><table><thead><tr><th>Date</th><th>New users</th><th>Earned</th><th>Requested</th><th>Paid</th><th>Reversed</th><th>Task rewards</th><th>Check-in</th><th>Mission</th></tr></thead><tbody>{rows.map(r=><tr key={r.day}><td>{r.day}</td><td>{r.new_users}</td><td>{money(r.earned)}</td><td>{money(r.withdrawal_requested)}</td><td>{money(r.withdrawal_paid)}</td><td>{money(r.withdrawal_reversed)}</td><td>{money(r.task_rewards)}</td><td>{money(r.checkin_rewards)}</td><td>{money(r.mission_rewards)}</td></tr>)}</tbody></table></div></Panel><Panel title="Data exports"><p className="muted">Export operational datasets visible to this Admin session. Payment account values are excluded from the withdrawal export.</p><div className="button-row"><button className="secondary" onClick={()=>downloadCsv('zenexpay-users.csv',data.users)}>Users CSV</button><button className="secondary" onClick={()=>downloadCsv('zenexpay-transactions.csv',data.transactions.map(({withdrawal_account,withdrawal_method,...x})=>x))}>Transactions CSV</button><button className="secondary" onClick={()=>downloadCsv('zenexpay-withdrawals.csv',data.withdrawals.map(({account_number,...x})=>x))}>Withdrawals CSV</button><button className="secondary" onClick={()=>downloadCsv('zenexpay-audit.csv',data.audit)}>Audit CSV</button></div></Panel></div>
}

function HealthPage({rpc}){const [checks,setChecks]=useState([]);const [loading,setLoading]=useState(false);const load=async()=>{setLoading(true);try{setChecks(await rpc('admin_system_health')||[])}catch(e){setChecks([{check_name:'database',ok:false,detail:e?.message||'Health RPC failed',checked_at:new Date().toISOString()}])}finally{setLoading(false)}};useEffect(()=>{load()},[]);return <div className="content"><section className="hero"><div><h2>System health</h2><p>Operational checks for database access, core tables, settings and realtime configuration.</p></div><button onClick={load}>{loading?'Checking…':'Run health check'}</button></section><Panel title="Checks">{checks.map(c=><div className="row" key={c.check_name}><div><b>{c.check_name}</b><small>{c.detail}</small></div><Badge value={c.ok?'healthy':'failed'}/></div>)}</Panel><Panel title="Emergency controls"><p className="muted">Use App Control for maintenance mode and feature switches. Financial actions remain protected by server-side permissions.</p></Panel></div>}

function Login({onLogin,message}){const[email,setEmail]=useState('');const[password,setPassword]=useState('');return <div className="login-screen"><div className="login-card"><div className="brand-mark big">Z</div><h1>ZenexPay Admin</h1><p>Sign in with an authorized Supabase admin account.</p>{message&&<div className="notice">{message}</div>}<input type="email" placeholder="Admin email" value={email} onChange={e=>setEmail(e.target.value)}/><input type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)} onKeyDown={e=>e.key==='Enter'&&onLogin(email,password)}/><button onClick={()=>onLogin(email,password)}>Sign in</button></div></div>}

createRoot(document.getElementById('root')).render(<App/>);
