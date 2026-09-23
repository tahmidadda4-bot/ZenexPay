import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { createClient } from '@supabase/supabase-js';
import './style.css';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

const money = (v) => `৳ ${Number(v || 0).toFixed(2)}`;

/* =========================
   LOGIN
========================= */

function Login({ onLogin }) {
  const [busy, setBusy] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setBusy(true);

    const f = new FormData(e.currentTarget);

    const { data, error } =
      await supabase.auth.signInWithPassword({
        email: f.get('email'),
        password: f.get('password'),
      });

    setBusy(false);

    if (error) {
      alert(error.message);
      return;
    }

    onLogin(data.session);
  }

  return (
    <main className="login">
      <form
        onSubmit={submit}
        className="panel login-card"
      >
        <div className="brand">💰</div>

        <h1>ZenexPay Admin</h1>

        <p>Secure management dashboard</p>

        <input
          name="email"
          type="email"
          placeholder="Admin email"
          required
        />

        <input
          name="password"
          type="password"
          placeholder="Password"
          required
        />

        <button disabled={busy}>
          {busy
            ? 'Signing in...'
            : 'Sign in'}
        </button>

        <small>
          Only users with the Supabase admin role
          can manage protected data.
        </small>
      </form>
    </main>
  );
}

/* =========================
   MAIN APP
========================= */

function App() {
  const [session, setSession] = useState(null);

  const [tab, setTab] =
    useState('dashboard');

  const [refreshing, setRefreshing] =
    useState(false);

  const [data, setData] = useState({
    users: [],
    tasks: [],
    subs: [],
    withdrawals: [],
  });

  const [stats, setStats] =
    useState({});

  /* -------------------------
     SESSION
  ------------------------- */

  useEffect(() => {
    supabase.auth
      .getSession()
      .then(({ data }) => {
        setSession(data.session);
      });
  }, []);

  /* -------------------------
     LOAD DATA
  ------------------------- */

  useEffect(() => {
    if (session) {
      load();
    }
  }, [session]);

  async function load() {
    if (refreshing) return;

    setRefreshing(true);

    try {
      async function q(
        table,
        select = '*'
      ) {
        const {
          data,
          error,
        } = await supabase
          .from(table)
          .select(select)
          .order(
            'created_at',
            {
              ascending: false,
            }
          )
          .limit(100);

        if (error) {
          console.error(
            `${table} error:`,
            error
          );

          throw error;
        }

        return data || [];
      }

      /*
       * IMPORTANT:
       *
       * profiles table does NOT currently
       * contain an email column.
       *
       * So we use the actual columns:
       * id
       * full_name
       * phone
       * status
       * created_at
       */

      const [
        users,
        tasks,
        subs,
        withdrawals,
      ] = await Promise.all([
        q(
          'profiles',
          'id,full_name,phone,status,created_at'
        ),

        q('tasks'),

        q(
          'task_submissions',
          'id,task_id,user_id,status,proof_text,admin_note,created_at'
        ),

        q(
          'withdrawals',
          'id,user_id,amount,method,account_number,status,admin_note,created_at'
        ),
      ]);

      setData({
        users,
        tasks,
        subs,
        withdrawals,
      });

      setStats({
        users: users.length,

        tasks: tasks.length,

        pendingSubs:
          subs.filter(
            x =>
              x.status ===
              'pending'
          ).length,

        pendingWithdrawals:
          withdrawals.filter(
            x =>
              x.status ===
              'pending'
          ).length,
      });

    } catch (error) {
      console.error(
        'Refresh error:',
        error
      );

      alert(
        `Refresh failed: ${
          error.message
        }`
      );

    } finally {
      setRefreshing(false);
    }
  }

  /* =========================
     APPROVE SUBMISSION
  ========================= */

  async function approve(id) {
    const { error } =
      await supabase.rpc(
        'approve_submission',
        {
          p_submission_id: id,
        }
      );

    if (error) {
      alert(error.message);
      return;
    }

    await load();
  }

  /* =========================
     REJECT SUBMISSION
  ========================= */

  async function reject(id) {
    const note =
      prompt(
        'Reason (optional):'
      ) || null;

    /*
     * Current database does not have
     * reject_submission RPC.
     *
     * Therefore update directly.
     */

    const { error } =
      await supabase
        .from('task_submissions')
        .update({
          status: 'rejected',
          admin_note: note,
        })
        .eq('id', id);

    if (error) {
      alert(error.message);
      return;
    }

    await load();
  }

  /* =========================
     WITHDRAWAL PROCESS
  ========================= */

  async function process(
    id,
    status
  ) {
    const note =
      prompt(
        'Admin note (optional):'
      ) || null;

    /*
     * Current RPC:
     *
     * process_withdrawal(
     *   p_withdrawal_id,
     *   p_status,
     *   p_note
     * )
     */

    const { error } =
      await supabase.rpc(
        'process_withdrawal',
        {
          p_withdrawal_id: id,
          p_status: status,
          p_note: note,
        }
      );

    if (error) {
      alert(error.message);
      return;
    }

    await load();
  }

  /* =========================
     LOGIN SCREEN
  ========================= */

  if (!session) {
    return (
      <Login
        onLogin={setSession}
      />
    );
  }

  /* =========================
     NAVIGATION
  ========================= */

  const nav = [
    [
      'dashboard',
      'Dashboard',
    ],
    [
      'users',
      'Users',
    ],
    [
      'tasks',
      'Tasks',
    ],
    [
      'subs',
      'Submissions',
    ],
    [
      'withdrawals',
      'Withdrawals',
    ],
  ];

  return (
    <div className="app">

      {/* SIDEBAR */}

      <aside>

        <div className="logo">
          💰
          <span>
            ZenexPay
          </span>
        </div>

        {nav.map(
          ([key, label]) => (
            <button
              key={key}
              className={
                tab === key
                  ? 'active'
                  : ''
              }
              onClick={() =>
                setTab(key)
              }
            >
              {label}
            </button>
          )
        )}

        <button
          className="logout"
          onClick={async () => {
            await supabase.auth.signOut();
            setSession(null);
          }}
        >
          Logout
        </button>

      </aside>

      {/* CONTENT */}

      <main className="content">

        <header>

          <div>
            <h1>
              {
                nav.find(
                  x =>
                    x[0] === tab
                )?.[1]
              }
            </h1>

            <p>
              ZenexPay management
              panel
            </p>
          </div>

          <button
            onClick={load}
            disabled={refreshing}
          >
            {refreshing
              ? 'Refreshing...'
              : 'Refresh'}
          </button>

        </header>

        {tab ===
          'dashboard' && (
          <Dashboard
            stats={stats}
            data={data}
          />
        )}

        {tab === 'users' && (
          <Table
            title="Users"
            rows={data.users}
            cols={[
              'full_name',
              'phone',
              'status',
              'created_at',
            ]}
          />
        )}

        {tab === 'tasks' && (
          <Tasks
            tasks={data.tasks}
            onRefresh={load}
          />
        )}

        {tab === 'subs' && (
          <Submissions
            rows={data.subs}
            onApprove={approve}
            onReject={reject}
          />
        )}

        {tab ===
          'withdrawals' && (
          <Withdrawals
            rows={data.withdrawals}
            onProcess={process}
          />
        )}

      </main>

    </div>
  );
}

/* =========================
   DASHBOARD
========================= */

function Dashboard({
  stats,
  data,
}) {
  return (
    <section>

      <div className="cards">

        {[
          [
            'Users',
            stats.users,
          ],

          [
            'Tasks',
            stats.tasks,
          ],

          [
            'Pending submissions',
            stats.pendingSubs,
          ],

          [
            'Pending withdrawals',
            stats.pendingWithdrawals,
          ],
        ].map(
          ([title, value]) => (
            <div
              className="panel stat"
              key={title}
            >
              <span>
                {title}
              </span>

              <strong>
                {value || 0}
              </strong>
            </div>
          )
        )}

      </div>

      <div className="grid2">

        {/* WITHDRAWALS */}

        <div className="panel">

          <h2>
            Recent withdrawals
          </h2>

          {data.withdrawals
            .slice(0, 6)
            .map(w => (
              <div
                className="row"
                key={w.id}
              >
                <span>
                  {w.method}
                </span>

                <b>
                  {money(
                    w.amount
                  )}
                </b>

                <em>
                  {w.status}
                </em>
              </div>
            ))}

        </div>

        {/* TASKS */}

        <div className="panel">

          <h2>
            Recent tasks
          </h2>

          {data.tasks
            .slice(0, 6)
            .map(t => (
              <div
                className="row"
                key={t.id}
              >
                <span>
                  {t.title}
                </span>

                <b>
                  {money(
                    t.reward
                  )}
                </b>

                <em>
                  {t.status}
                </em>
              </div>
            ))}

        </div>

      </div>

    </section>
  );
}

/* =========================
   TABLE
========================= */

function Table({
  title,
  rows,
  cols,
}) {
  return (
    <div className="panel">

      <h2>{title}</h2>

      <div className="tablewrap">

        <table>

          <thead>
            <tr>
              {cols.map(
                column => (
                  <th
                    key={column}
                  >
                    {column}
                  </th>
                )
              )}
            </tr>
          </thead>

          <tbody>

            {rows.map(row => (
              <tr
                key={row.id}
              >

                {cols.map(
                  column => (
                    <td
                      key={column}
                    >
                      {String(
                        row[
                          column
                        ] ?? ''
                      )}
                    </td>
                  )
                )}

              </tr>
            ))}

          </tbody>

        </table>

      </div>

    </div>
  );
}

/* =========================
   TASKS
========================= */

function Tasks({
  tasks,
  onRefresh,
}) {
  const [open, setOpen] =
    useState(false);

  const [saving, setSaving] =
    useState(false);

  const [form, setForm] =
    useState({
      title: '',
      description: '',
      instructions: '',
      reward: '',
      status: 'published',
      max_submissions: '',
    });

  async function save(e) {
    e.preventDefault();

    if (saving) return;

    setSaving(true);

    try {
      const {
        data: userData,
        error: userError,
      } =
        await supabase.auth.getUser();

      if (
        userError ||
        !userData?.user
      ) {
        throw new Error(
          'Unable to identify admin user.'
        );
      }

      const { error } =
        await supabase
          .from('tasks')
          .insert({
            title: form.title,
            description:
              form.description,
            instructions:
              form.instructions,
            reward:
              Number(
                form.reward
              ),
            status:
              form.status,
            max_submissions:
              form.max_submissions
                ? Number(
                    form.max_submissions
                  )
                : null,
            created_by:
              userData.user.id,
          });

      if (error) {
        throw error;
      }

      setOpen(false);

      setForm({
        title: '',
        description: '',
        instructions: '',
        reward: '',
        status: 'published',
        max_submissions: '',
      });

      await onRefresh();

    } catch (error) {
      alert(error.message);

    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="panel">

      <div className="toolbar">

        <h2>
          Tasks
        </h2>

        <button
          onClick={() =>
            setOpen(!open)
          }
        >
          + Add task
        </button>

      </div>

      {open && (
        <form
          className="taskform"
          onSubmit={save}
        >

          <input
            placeholder="Title"
            required
            value={form.title}
            onChange={e =>
              setForm({
                ...form,
                title:
                  e.target.value,
              })
            }
          />

          <input
            placeholder="Reward"
            type="number"
            step="0.01"
            min="0"
            required
            value={form.reward}
            onChange={e =>
              setForm({
                ...form,
                reward:
                  e.target.value,
              })
            }
          />

          <input
            placeholder="Max submissions (optional)"
            type="number"
            min="1"
            value={
              form.max_submissions
            }
            onChange={e =>
              setForm({
                ...form,
                max_submissions:
                  e.target.value,
              })
            }
          />

          <select
            value={form.status}
            onChange={e =>
              setForm({
                ...form,
                status:
                  e.target.value,
              })
            }
          >
            <option value="published">
              published
            </option>

            <option value="draft">
              draft
            </option>

            <option value="paused">
              paused
            </option>

            <option value="closed">
              closed
            </option>
          </select>

          <textarea
            placeholder="Description"
            value={
              form.description
            }
            onChange={e =>
              setForm({
                ...form,
                description:
                  e.target.value,
              })
            }
          />

          <textarea
            placeholder="Instructions"
            value={
              form.instructions
            }
            onChange={e =>
              setForm({
                ...form,
                instructions:
                  e.target.value,
              })
            }
          />

          <button
            type="submit"
            disabled={saving}
          >
            {saving
              ? 'Saving...'
              : 'Save task'}
          </button>

        </form>
      )}

      <div className="list">

        {tasks.map(t => (
          <div
            className="row"
            key={t.id}
          >

            <div>
              <b>
                {t.title}
              </b>

              <small>
                {t.description}
              </small>
            </div>

            <b>
              {money(t.reward)}
            </b>

            <em>
              {t.status}
            </em>

          </div>
        ))}

      </div>

    </div>
  );
}

/* =========================
   SUBMISSIONS
========================= */

function Submissions({
  rows,
  onApprove,
  onReject,
}) {
  return (
    <div className="panel">

      <h2>
        Task submissions
      </h2>

      {rows.map(r => (
        <div
          className="item"
          key={r.id}
        >

          <div>

            <b>
              {r.id.slice(0, 8)}
              ...
            </b>

            <small>
              User: {r.user_id}
            </small>

            <p>
              {r.proof_text ||
                'No proof text'}
            </p>

            {r.admin_note && (
              <small>
                Admin note:{' '}
                {r.admin_note}
              </small>
            )}

          </div>

          <em>
            {r.status}
          </em>

          {r.status ===
            'pending' && (
            <div className="actions">

              <button
                onClick={() =>
                  onApprove(r.id)
                }
              >
                Approve
              </button>

              <button
                className="danger"
                onClick={() =>
                  onReject(r.id)
                }
              >
                Reject
              </button>

            </div>
          )}

        </div>
      ))}

    </div>
  );
}

/* =========================
   WITHDRAWALS
========================= */

function Withdrawals({
  rows,
  onProcess,
}) {
  return (
    <div className="panel">

      <h2>
        Withdrawals
      </h2>

      {rows.map(r => (
        <div
          className="item"
          key={r.id}
        >

          <div>

            <b>
              {money(r.amount)}
              {' • '}
              {r.method}
            </b>

            <small>
              {r.account_number}
            </small>

            <small>
              User: {r.user_id}
            </small>

            {r.admin_note && (
              <small>
                Admin note:{' '}
                {r.admin_note}
              </small>
            )}

          </div>

          <em>
            {r.status}
          </em>

          {[
            'pending',
            'processing',
          ].includes(
            r.status
          ) && (
            <div className="actions">

              <button
                onClick={() =>
                  onProcess(
                    r.id,
                    'paid'
                  )
                }
              >
                Mark paid
              </button>

              <button
                className="danger"
                onClick={() =>
                  onProcess(
                    r.id,
                    'rejected'
                  )
                }
              >
                Reject
              </button>

            </div>
          )}

        </div>
      ))}

    </div>
  );
}

/* =========================
   START APP
========================= */

createRoot(
  document.getElementById('root')
).render(
  <App />
);
