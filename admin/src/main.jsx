import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import { createClient } from "@supabase/supabase-js";
import "./style.css";

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

const VERSION = "ZenexPay Admin v3.0";

const money = (value) => {
  const n = Number(value || 0);
  return `৳ ${n.toFixed(2)}`;
};

const dateText = (value) => {
  if (!value) return "-";

  try {
    return new Date(value).toLocaleString();
  } catch {
    return "-";
  }
};

const shortId = (value) => {
  if (!value) return "-";
  return `${String(value).slice(0, 8)}...`;
};

async function getRows(table) {
  const { data, error } = await supabase
    .from(table)
    .select("*");

  if (error) throw error;

  return data || [];
}

function App() {
  const [session, setSession] = useState(null);
  const [checking, setChecking] = useState(true);

  const [users, setUsers] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [submissions, setSubmissions] = useState([]);
  const [withdrawals, setWithdrawals] = useState([]);
  const [transactions, setTransactions] = useState([]);

  const [page, setPage] = useState("dashboard");

  const [taskTitle, setTaskTitle] = useState("");
  const [taskDescription, setTaskDescription] = useState("");
  const [taskReward, setTaskReward] = useState("");
  const [taskType, setTaskType] = useState("general");

  const [savingTask, setSavingTask] = useState(false);
  const [busyId, setBusyId] = useState(null);

  useEffect(() => {
    init();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(
      (_event, newSession) => {
        setSession(newSession);
      }
    );

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (session) {
      loadAll();
    }
  }, [session]);

  async function init() {
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      setSession(session);
    } catch (error) {
      console.error(error);
    } finally {
      setChecking(false);
    }
  }

  async function login(email, password) {
    const { error } =
      await supabase.auth.signInWithPassword({
        email,
        password,
      });

    if (error) {
      alert(`Login failed:\n\n${error.message}`);
    }
  }

  async function logout() {
    await supabase.auth.signOut();

    setSession(null);
    setUsers([]);
    setTasks([]);
    setSubmissions([]);
    setWithdrawals([]);
    setTransactions([]);
  }

  async function loadAll() {
    const errors = [];

    try {
      setUsers(await getRows("profiles"));
    } catch (error) {
      console.error("profiles:", error);
      errors.push(`Users: ${error.message}`);
    }

    try {
      setTasks(await getRows("tasks"));
    } catch (error) {
      console.error("tasks:", error);
      errors.push(`Tasks: ${error.message}`);
    }

    try {
      setSubmissions(
        await getRows("task_submissions")
      );
    } catch (error) {
      console.error("submissions:", error);
      errors.push(
        `Submissions: ${error.message}`
      );
    }

    try {
      setWithdrawals(
        await getRows("withdrawals")
      );
    } catch (error) {
      console.error("withdrawals:", error);
      errors.push(
        `Withdrawals: ${error.message}`
      );
    }

    try {
      setTransactions(
        await getRows("transactions")
      );
    } catch (error) {
      console.error("transactions:", error);
      errors.push(
        `Transactions: ${error.message}`
      );
    }

    if (errors.length) {
      console.error(errors);

      alert(
        "Some dashboard data could not be loaded:\n\n" +
          errors.join("\n\n")
      );
    }
  }

  async function addTask() {
    const title = taskTitle.trim();
    const description = taskDescription.trim();
    const reward = Number(taskReward);

    if (!title) {
      alert("Task title is required.");
      return;
    }

    if (!Number.isFinite(reward) || reward <= 0) {
      alert("Enter a valid reward.");
      return;
    }

    setSavingTask(true);

    try {
      const { error } = await supabase
        .from("tasks")
        .insert({
          title,
          description,
          reward,
          type: taskType,
        });

      if (error) throw error;

      setTaskTitle("");
      setTaskDescription("");
      setTaskReward("");
      setTaskType("general");

      await loadAll();

      alert("Task added successfully.");
    } catch (error) {
      console.error(error);

      alert(
        `Add Task failed:\n\n${error.message}`
      );
    } finally {
      setSavingTask(false);
    }
  }

  async function approveSubmission(id) {
    if (!id) return;

    setBusyId(id);

    try {
      const { error } =
        await supabase.rpc(
          "approve_submission",
          {
            p_submission_id: id,
          }
        );

      if (error) throw error;

      await loadAll();

      alert("Submission approved.");
    } catch (error) {
      console.error(error);

      alert(
        `Approve failed:\n\n${error.message}`
      );
    } finally {
      setBusyId(null);
    }
  }

  async function rejectSubmission(id) {
    if (!id) return;

    const reason = window.prompt(
      "Enter rejection reason:"
    );

    if (reason === null) return;

    setBusyId(id);

    try {
      const { error } =
        await supabase
          .from("task_submissions")
          .update({
            status: "rejected",
            rejection_reason:
              reason.trim(),
            reviewed_at:
              new Date().toISOString(),
            reviewed_by:
              session.user.id,
          })
          .eq("id", id);

      if (error) throw error;

      await loadAll();

      alert("Submission rejected.");
    } catch (error) {
      console.error(error);

      alert(
        `Reject failed:\n\n${error.message}`
      );
    } finally {
      setBusyId(null);
    }
  }

  async function processWithdrawal(
    id,
    status
  ) {
    if (!id) return;

    const action =
      status === "approved"
        ? "approve"
        : "reject";

    const confirmed = window.confirm(
      `Are you sure you want to ${action} this withdrawal?`
    );

    if (!confirmed) return;

    const note =
      window.prompt(
        "Admin note (optional):"
      ) || "";

    setBusyId(id);

    try {
      const { error } =
        await supabase.rpc(
          "process_withdrawal",
          {
            p_withdrawal_id: id,
            p_status: status,
            p_note: note,
          }
        );

      if (error) throw error;

      await loadAll();

      alert(
        status === "approved"
          ? "Withdrawal approved."
          : "Withdrawal rejected."
      );
    } catch (error) {
      console.error(error);

      alert(
        `Withdrawal update failed:\n\n${error.message}`
      );
    } finally {
      setBusyId(null);
    }
  }

  const pendingSubmissions = useMemo(
    () =>
      submissions.filter(
        (x) => x.status === "pending"
      ),
    [submissions]
  );

  const pendingWithdrawals = useMemo(
    () =>
      withdrawals.filter(
        (x) => x.status === "pending"
      ),
    [withdrawals]
  );

  const totalEarnings = useMemo(() => {
    return transactions.reduce(
      (sum, item) =>
        sum + Number(item.amount || 0),
      0
    );
  }, [transactions]);

  const completedSubmissions =
    submissions.filter(
      (x) =>
        x.status === "approved" ||
        x.status === "completed"
    ).length;

  const rejectedSubmissions =
    submissions.filter(
      (x) => x.status === "rejected"
    ).length;

  const completionRate =
    submissions.length > 0
      ? Math.round(
          (completedSubmissions /
            submissions.length) *
            100
        )
      : 0;

  if (checking) {
    return (
      <div className="loading-screen">
        <div className="loading-logo">
          Z
        </div>
        <div>Loading ZenexPay...</div>
      </div>
    );
  }

  if (!session) {
    return <Login onLogin={login} />;
  }

  return (
    <div className="admin-shell">

      <Sidebar
        page={page}
        setPage={setPage}
        logout={logout}
      />

      <main className="main-area">

        <Topbar
          page={page}
          session={session}
        />

        {page === "dashboard" && (
          <Dashboard
            users={users}
            tasks={tasks}
            submissions={submissions}
            withdrawals={withdrawals}
            transactions={transactions}
            pendingSubmissions={
              pendingSubmissions
            }
            pendingWithdrawals={
              pendingWithdrawals
            }
            totalEarnings={
              totalEarnings
            }
            completionRate={
              completionRate
            }
            rejectedSubmissions={
              rejectedSubmissions
            }
            setPage={setPage}
            approveSubmission={
              approveSubmission
            }
            rejectSubmission={
              rejectSubmission
            }
            processWithdrawal={
              processWithdrawal
            }
            busyId={busyId}
          />
        )}

        {page === "users" && (
          <UsersPage users={users} />
        )}

        {page === "tasks" && (
          <TasksPage
            tasks={tasks}
            taskTitle={taskTitle}
            setTaskTitle={setTaskTitle}
            taskDescription={
              taskDescription
            }
            setTaskDescription={
              setTaskDescription
            }
            taskReward={taskReward}
            setTaskReward={
              setTaskReward
            }
            taskType={taskType}
            setTaskType={setTaskType}
            addTask={addTask}
            savingTask={savingTask}
          />
        )}

        {page === "submissions" && (
          <SubmissionsPage
            submissions={submissions}
            approveSubmission={
              approveSubmission
            }
            rejectSubmission={
              rejectSubmission
            }
            busyId={busyId}
          />
        )}

        {page === "withdrawals" && (
          <WithdrawalsPage
            withdrawals={withdrawals}
            processWithdrawal={
              processWithdrawal
            }
            busyId={busyId}
          />
        )}

        {page === "transactions" && (
          <TransactionsPage
            transactions={transactions}
          />
        )}

      </main>
    </div>
  );
}

/* =========================================================
   SIDEBAR
   ========================================================= */

function Sidebar({
  page,
  setPage,
  logout,
}) {
  const items = [
    ["dashboard", "⌂", "Dashboard"],
    ["users", "♙", "Users"],
    ["tasks", "▣", "Tasks"],
    ["submissions", "✓", "Submissions"],
    ["withdrawals", "৳", "Withdrawals"],
    ["transactions", "↗", "Transactions"],
  ];

  return (
    <aside className="sidebar">

      <div className="brand">

        <div className="brand-mark">
          Z
        </div>

        <div>
          <div className="brand-name">
            Zenex<span>Pay</span>
          </div>

          <div className="brand-sub">
            ADMIN PANEL
          </div>
        </div>

      </div>

      <nav className="side-nav">

        {items.map(
          ([id, icon, label]) => (
            <button
              key={id}
              className={
                page === id
                  ? "nav-item active"
                  : "nav-item"
              }
              onClick={() =>
                setPage(id)
              }
            >
              <span className="nav-icon">
                {icon}
              </span>

              <span>{label}</span>
            </button>
          )
        )}

      </nav>

      <div className="sidebar-bottom">

        <div className="online-dot">
          <span />
          System Online
        </div>

        <div className="version">
          {VERSION}
        </div>

        <button
          className="logout-side"
          onClick={logout}
        >
          ↪ Logout
        </button>

      </div>

    </aside>
  );
}

/* =========================================================
   TOPBAR
   ========================================================= */

function Topbar({
  page,
  session,
}) {
  const names = {
    dashboard: "Dashboard",
    users: "Users",
    tasks: "Tasks",
    submissions: "Submissions",
    withdrawals: "Withdrawals",
    transactions: "Transactions",
  };

  return (
    <header className="topbar">

      <div className="mobile-brand">
        <div className="brand-mark">
          Z
        </div>

        <div className="brand-name">
          Zenex<span>Pay</span>
        </div>
      </div>

      <div className="search-box">
        <span>⌕</span>
        <input
          placeholder="Search users, tasks, transactions..."
        />
      </div>

      <div className="top-right">

        <div className="notification">
          ◉
        </div>

        <div className="admin-profile">

          <div className="avatar">
            {(session?.user?.email || "A")
              .charAt(0)
              .toUpperCase()}
          </div>

          <div className="admin-info">
            <strong>
              Admin
            </strong>

            <span>
              {names[page] ||
                "Super Admin"}
            </span>
          </div>

        </div>

      </div>

    </header>
  );
}

/* =========================================================
   DASHBOARD
   ========================================================= */

function Dashboard({
  users,
  tasks,
  submissions,
  withdrawals,
  transactions,
  pendingSubmissions,
  pendingWithdrawals,
  totalEarnings,
  completionRate,
  rejectedSubmissions,
  setPage,
  approveSubmission,
  rejectSubmission,
  processWithdrawal,
  busyId,
}) {
  return (
    <div className="content">

      <div className="page-heading">

        <div>
          <h1>Dashboard</h1>

          <p>
            Welcome back, Admin. Here's
            what's happening with your
            platform.
          </p>
        </div>

        <div className="today-badge">
          <span>◷</span>
          Today
        </div>

      </div>

      {/* STAT CARDS */}

      <div className="stat-grid">

        <StatCard
          icon="♙"
          label="Total Users"
          value={users.length}
          tone="blue"
          trend="+12%"
        />

        <StatCard
          icon="✓"
          label="Total Tasks"
          value={tasks.length}
          tone="green"
          trend="+5%"
        />

        <StatCard
          icon="▣"
          label="Total Submissions"
          value={submissions.length}
          tone="purple"
          trend="+18%"
        />

        <StatCard
          icon="৳"
          label="Total Withdrawals"
          value={withdrawals.length}
          tone="yellow"
          trend="+10%"
        />

      </div>

      {/* MAIN ANALYTICS */}

      <div className="analytics-grid">

        <section className="panel earnings-panel">

          <div className="panel-header">

            <div>
              <h2>Earnings Overview</h2>
              <p>
                Platform transaction activity
              </p>
            </div>

            <select>
              <option>
                Last 7 days
              </option>
              <option>
                Last 30 days
              </option>
            </select>

          </div>

          <div className="chart-area">

            <div className="chart-y">
              <span>৳ 2,000</span>
              <span>৳ 1,500</span>
              <span>৳ 1,000</span>
              <span>৳ 500</span>
              <span>৳ 0</span>
            </div>

            <div className="chart">

              <div className="chart-grid">
                <i />
                <i />
                <i />
                <i />
                <i />
              </div>

              <svg
                viewBox="0 0 700 250"
                preserveAspectRatio="none"
                className="chart-svg"
              >
                <defs>
                  <linearGradient
                    id="areaGradient"
                    x1="0"
                    x2="0"
                    y1="0"
                    y2="1"
                  >
                    <stop
                      offset="0%"
                      stopColor="#8d5cff"
                      stopOpacity=".35"
                    />

                    <stop
                      offset="100%"
                      stopColor="#8d5cff"
                      stopOpacity="0"
                    />
                  </linearGradient>
                </defs>

                <path
                  d="
                    M0 190
                    C70 165 85 175 125 145
                    S205 125 250 135
                    S330 95 375 105
                    S455 75 500 82
                    S600 45 700 25
                    L700 250
                    L0 250
                    Z
                  "
                  fill="url(#areaGradient)"
                />

                <path
                  d="
                    M0 190
                    C70 165 85 175 125 145
                    S205 125 250 135
                    S330 95 375 105
                    S455 75 500 82
                    S600 45 700 25
                  "
                  fill="none"
                  stroke="#8d5cff"
                  strokeWidth="4"
                  strokeLinecap="round"
                />

              </svg>

              <div className="chart-labels">
                <span>Sep 16</span>
                <span>Sep 17</span>
                <span>Sep 18</span>
                <span>Sep 19</span>
                <span>Sep 20</span>
                <span>Sep 21</span>
                <span>Sep 22</span>
              </div>

            </div>

          </div>

          <div className="earnings-total">
            <span>Total transaction value</span>
            <strong>
              {money(totalEarnings)}
            </strong>
          </div>

        </section>

        {/* COMPLETION */}

        <section className="panel completion-panel">

          <div className="panel-header">
            <div>
              <h2>Task Completion</h2>
              <p>
                Submission performance
              </p>
            </div>
          </div>

          <div
            className="donut"
            style={{
              "--percent":
                `${completionRate}%`,
            }}
          >
            <div>
              <strong>
                {completionRate}%
              </strong>
              <span>Completed</span>
            </div>
          </div>

          <div className="legend">

            <div>
              <i className="green-dot" />
              <span>Completed</span>
              <strong>
                {submissions.length
                  ? Math.round(
                      (submissions.filter(
                        x =>
                          x.status ===
                            "approved" ||
                          x.status ===
                            "completed"
                      ).length /
                        submissions.length) *
                        100
                    )
                  : 0}
                %
              </strong>
            </div>

            <div>
              <i className="yellow-dot" />
              <span>Pending</span>
              <strong>
                {submissions.length
                  ? Math.round(
                      (pendingSubmissions.length /
                        submissions.length) *
                        100
                    )
                  : 0}
                %
              </strong>
            </div>

            <div>
              <i className="red-dot" />
              <span>Rejected</span>
              <strong>
                {submissions.length
                  ? Math.round(
                      (rejectedSubmissions /
                        submissions.length) *
                        100
                    )
                  : 0}
                %
              </strong>
            </div>

          </div>

        </section>

      </div>

      {/* LOWER DASHBOARD */}

      <div className="dashboard-lower">

        <section className="panel large-panel">

          <div className="panel-header">

            <div>
              <h2>Recent Submissions</h2>
              <p>
                Latest task submissions
              </p>
            </div>

            <button
              className="text-button"
              onClick={() =>
                setPage("submissions")
              }
            >
              View All →
            </button>

          </div>

          <SubmissionTable
            submissions={
              submissions.slice(0, 5)
            }
            approveSubmission={
              approveSubmission
            }
            rejectSubmission={
              rejectSubmission
            }
            busyId={busyId}
          />

        </section>

        <section className="panel quick-panel">

          <div className="panel-header">
            <div>
              <h2>Quick Actions</h2>
              <p>
                Manage your platform
              </p>
            </div>
          </div>

          <button
            className="quick-action purple"
            onClick={() =>
              setPage("tasks")
            }
          >
            <span>▣</span>
            <div>
              <strong>Add New Task</strong>
              <small>
                Create earning task
              </small>
            </div>
            <b>→</b>
          </button>

          <button
            className="quick-action blue"
            onClick={() =>
              setPage("users")
            }
          >
            <span>♙</span>
            <div>
              <strong>View All Users</strong>
              <small>
                Manage members
              </small>
            </div>
            <b>→</b>
          </button>

          <button
            className="quick-action yellow"
            onClick={() =>
              setPage("withdrawals")
            }
          >
            <span>৳</span>
            <div>
              <strong>
                View Withdrawals
              </strong>
              <small>
                {pendingWithdrawals.length}
                {" "}pending
              </small>
            </div>
            <b>→</b>
          </button>

          <button
            className="quick-action green"
            onClick={() =>
              setPage("transactions")
            }
          >
            <span>↗</span>
            <div>
              <strong>
                View Transactions
              </strong>
              <small>
                Financial activity
              </small>
            </div>
            <b>→</b>
          </button>

        </section>

      </div>

      <div className="bottom-grid">

        <RecentWithdrawals
          withdrawals={
            withdrawals.slice(0, 5)
          }
          setPage={setPage}
        />

        <TopUsers
          users={users}
          setPage={setPage}
        />

        <QuickStats
          users={users}
          submissions={submissions}
          withdrawals={withdrawals}
          pendingSubmissions={
            pendingSubmissions
          }
        />

      </div>

    </div>
  );
}

/* =========================================================
   STAT CARD
   ========================================================= */

function StatCard({
  icon,
  label,
  value,
  tone,
  trend,
}) {
  return (
    <div className={`stat-card ${tone}`}>

      <div className="stat-icon">
        {icon}
      </div>

      <div className="stat-info">
        <span>{label}</span>

        <strong>
          {value.toLocaleString()}
        </strong>

        <small>
          <b>↗ {trend}</b>
          {" "}from last period
        </small>
      </div>

    </div>
  );
}

/* =========================================================
   SUBMISSION TABLE
   ========================================================= */

function SubmissionTable({
  submissions,
  approveSubmission,
  rejectSubmission,
  busyId,
}) {
  if (!submissions.length) {
    return (
      <div className="empty-state">
        <span>▣</span>
        No submissions found.
      </div>
    );
  }

  return (
    <div className="data-table-wrap">

      <table className="modern-table">

        <thead>
          <tr>
            <th>User</th>
            <th>Task</th>
            <th>Proof</th>
            <th>Status</th>
            <th>Action</th>
          </tr>
        </thead>

        <tbody>

          {submissions.map(item => (

            <tr key={item.id}>

              <td>
                <div className="user-cell">
                  <div className="mini-avatar">
                    U
                  </div>

                  <div>
                    <strong>
                      {shortId(
                        item.user_id
                      )}
                    </strong>

                    <small>
                      User
                    </small>
                  </div>
                </div>
              </td>

              <td>
                {shortId(
                  item.task_id
                )}
              </td>

              <td>
                <span className="proof-text">
                  {item.proof_text ||
                    item.proof_url ||
                    "-"}
                </span>
              </td>

              <td>
                <StatusBadge
                  status={
                    item.status
                  }
                />
              </td>

              <td>

                {item.status ===
                  "pending" ? (

                  <div className="action-buttons">

                    <button
                      className="approve-btn"
                      disabled={
                        busyId === item.id
                      }
                      onClick={() =>
                        approveSubmission(
                          item.id
                        )
                      }
                    >
                      Approve
                    </button>

                    <button
                      className="reject-btn"
                      disabled={
                        busyId === item.id
                      }
                      onClick={() =>
                        rejectSubmission(
                          item.id
                        )
                      }
                    >
                      Reject
                    </button>

                  </div>

                ) : (
                  <span className="dash">
                    —
                  </span>
                )}

              </td>

            </tr>

          ))}

        </tbody>

      </table>

    </div>
  );
}

/* =========================================================
   STATUS
   ========================================================= */

function StatusBadge({
  status,
}) {
  const value =
    String(status || "unknown")
      .toLowerCase();

  let cls = "status-pending";

  if (
    value === "approved" ||
    value === "completed"
  ) {
    cls = "status-approved";
  }

  if (
    value === "rejected" ||
    value === "failed"
  ) {
    cls = "status-rejected";
  }

  return (
    <span className={`status ${cls}`}>
      <i />
      {status || "Unknown"}
    </span>
  );
}

/* =========================================================
   WITHDRAWALS
   ========================================================= */

function RecentWithdrawals({
  withdrawals,
  setPage,
}) {
  return (
    <section className="panel">

      <div className="panel-header">

        <div>
          <h2>Recent Withdrawals</h2>
          <p>
            Latest payout requests
          </p>
        </div>

        <button
          className="text-button"
          onClick={() =>
            setPage("withdrawals")
          }
        >
          View All →
        </button>

      </div>

      <div className="simple-list">

        {withdrawals.length === 0 ? (
          <div className="empty-state">
            No withdrawals found.
          </div>
        ) : (
          withdrawals.map(item => (

            <div
              className="list-row"
              key={item.id}
            >

              <div className="row-icon yellow">
                ৳
              </div>

              <div className="row-main">
                <strong>
                  {shortId(
                    item.user_id
                  )}
                </strong>

                <small>
                  {item.method ||
                    "Withdrawal"}
                </small>
              </div>

              <strong className="row-amount">
                {money(item.amount)}
              </strong>

              <StatusBadge
                status={item.status}
              />

            </div>

          ))
        )}

      </div>

    </section>
  );
}

/* =========================================================
   TOP USERS
   ========================================================= */

function TopUsers({
  users,
  setPage,
}) {
  return (
    <section className="panel">

      <div className="panel-header">

        <div>
          <h2>Top Users</h2>
          <p>
            Registered members
          </p>
        </div>

        <button
          className="text-button"
          onClick={() =>
            setPage("users")
          }
        >
          View All →
        </button>

      </div>

      <div className="simple-list">

        {users.length === 0 ? (
          <div className="empty-state">
            No users found.
          </div>
        ) : (
          users.slice(0, 5).map(
            (user, index) => (

              <div
                className="list-row"
                key={user.id}
              >

                <div className="rank">
                  #{index + 1}
                </div>

                <div className="mini-avatar">
                  {(user.full_name ||
                    "U")
                    .charAt(0)
                    .toUpperCase()}
                </div>

                <div className="row-main">
                  <strong>
                    {user.full_name ||
                      "User"}
                  </strong>

                  <small>
                    {user.phone ||
                      "Member"}
                  </small>
                </div>

                <span className="member-dot">
                  ●
                </span>

              </div>

            )
          )
        )}

      </div>

    </section>
  );
}

/* =========================================================
   QUICK STATS
   ========================================================= */

function QuickStats({
  users,
  submissions,
  withdrawals,
  pendingSubmissions,
}) {
  return (
    <section className="panel">

      <div className="panel-header">

        <div>
          <h2>Quick Stats</h2>
          <p>
            Platform snapshot
          </p>
        </div>

      </div>

      <div className="quick-stats">

        <div className="qs green">
          <span>✓</span>
          <div>
            <small>
              Today's Activity
            </small>
            <strong>
              {submissions.length}
            </strong>
          </div>
        </div>

        <div className="qs yellow">
          <span>৳</span>
          <div>
            <small>
              Pending Withdrawals
            </small>
            <strong>
              {withdrawals.filter(
                x =>
                  x.status ===
                  "pending"
              ).length}
            </strong>
          </div>
        </div>

        <div className="qs blue">
          <span>♙</span>
          <div>
            <small>
              Total Users
            </small>
            <strong>
              {users.length}
            </strong>
          </div>
        </div>

        <div className="qs purple">
          <span>▣</span>
          <div>
            <small>
              Pending Submissions
            </small>
            <strong>
              {pendingSubmissions.length}
            </strong>
          </div>
        </div>

      </div>

    </section>
  );
}

/* =========================================================
   USERS PAGE
   ========================================================= */

function UsersPage({
  users,
}) {
  return (
    <PageContainer
      title="Users"
      subtitle="Manage registered ZenexPay members."
    >

      <div className="panel">

        <div className="data-table-wrap">

          <table className="modern-table">

            <thead>
              <tr>
                <th>Name</th>
                <th>Phone</th>
                <th>Status</th>
                <th>Created</th>
              </tr>
            </thead>

            <tbody>

              {users.map(user => (

                <tr key={user.id}>

                  <td>
                    <div className="user-cell">

                      <div className="mini-avatar">
                        {(user.full_name ||
                          "U")
                          .charAt(0)
                          .toUpperCase()}
                      </div>

                      <div>
                        <strong>
                          {user.full_name ||
                            "Unnamed User"}
                        </strong>

                        <small>
                          {shortId(
                            user.id
                          )}
                        </small>
                      </div>

                    </div>
                  </td>

                  <td>
                    {user.phone ||
                      "-"}
                  </td>

                  <td>
                    <StatusBadge
                      status={
                        user.status ||
                        "active"
                      }
                    />
                  </td>

                  <td>
                    {dateText(
                      user.created_at
                    )}
                  </td>

                </tr>

              ))}

            </tbody>

          </table>

        </div>

      </div>

    </PageContainer>
  );
}

/* =========================================================
   TASKS PAGE
   ========================================================= */

function TasksPage({
  tasks,
  taskTitle,
  setTaskTitle,
  taskDescription,
  setTaskDescription,
  taskReward,
  setTaskReward,
  taskType,
  setTaskType,
  addTask,
  savingTask,
}) {
  return (
    <PageContainer
      title="Tasks"
      subtitle="Create and manage earning tasks."
    >

      <section className="panel task-create">

        <div className="panel-header">
          <div>
            <h2>Create New Task</h2>
            <p>
              Add a new earning opportunity.
            </p>
          </div>
        </div>

        <div className="task-form">

          <input
            value={taskTitle}
            onChange={e =>
              setTaskTitle(
                e.target.value
              )
            }
            placeholder="Task title"
          />

          <textarea
            value={taskDescription}
            onChange={e =>
              setTaskDescription(
                e.target.value
              )
            }
            placeholder="Task description"
            rows="4"
          />

          <div className="form-row">

            <input
              value={taskReward}
              onChange={e =>
                setTaskReward(
                  e.target.value
                )
              }
              type="number"
              min="0"
              step="0.01"
              placeholder="Reward"
            />

            <select
              value={taskType}
              onChange={e =>
                setTaskType(
                  e.target.value
                )
              }
            >
              <option value="general">
                General
              </option>
              <option value="video">
                Video
              </option>
              <option value="social">
                Social
              </option>
              <option value="app">
                App
              </option>
              <option value="survey">
                Survey
              </option>
            </select>

          </div>

          <button
            className="primary-large"
            onClick={addTask}
            disabled={savingTask}
          >
            {savingTask
              ? "Creating..."
              : "＋ Create Task"}
          </button>

        </div>

      </section>

      <section className="panel">

        <div className="panel-header">

          <div>
            <h2>All Tasks</h2>
            <p>
              {tasks.length} task(s)
            </p>
          </div>

        </div>

        <div className="data-table-wrap">

          <table className="modern-table">

            <thead>
              <tr>
                <th>Title</th>
                <th>Type</th>
                <th>Reward</th>
                <th>Status</th>
              </tr>
            </thead>

            <tbody>

              {tasks.map(task => (

                <tr key={task.id}>

                  <td>
                    <strong>
                      {task.title ||
                        "-"}
                    </strong>

                    <small className="table-sub">
                      {task.description ||
                        ""}
                    </small>
                  </td>

                  <td>
                    {task.type ||
                      "general"}
                  </td>

                  <td className="money">
                    {money(
                      task.reward
                    )}
                  </td>

                  <td>
                    <StatusBadge
                      status={
                        task.status ||
                        "active"
                      }
                    />
                  </td>

                </tr>

              ))}

            </tbody>

          </table>

        </div>

      </section>

    </PageContainer>
  );
}

/* =========================================================
   SUBMISSIONS PAGE
   ========================================================= */

function SubmissionsPage({
  submissions,
  approveSubmission,
  rejectSubmission,
  busyId,
}) {
  return (
    <PageContainer
      title="Submissions"
      subtitle="Review user task submissions."
    >

      <section className="panel">

        <SubmissionTable
          submissions={submissions}
          approveSubmission={
            approveSubmission
          }
          rejectSubmission={
            rejectSubmission
          }
          busyId={busyId}
        />

      </section>

    </PageContainer>
  );
}

/* =========================================================
   WITHDRAWALS PAGE
   ========================================================= */

function WithdrawalsPage({
  withdrawals,
  processWithdrawal,
  busyId,
}) {
  return (
    <PageContainer
      title="Withdrawals"
      subtitle="Review and process payout requests."
    >

      <section className="panel">

        <div className="data-table-wrap">

          <table className="modern-table">

            <thead>
              <tr>
                <th>User</th>
                <th>Amount</th>
                <th>Method</th>
                <th>Account</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>

            <tbody>

              {withdrawals.map(item => (

                <tr key={item.id}>

                  <td>
                    {shortId(
                      item.user_id
                    )}
                  </td>

                  <td className="money">
                    {money(
                      item.amount
                    )}
                  </td>

                  <td>
                    {item.method ||
                      "-"}
                  </td>

                  <td>
                    {item.account_number ||
                      "-"}
                  </td>

                  <td>
                    <StatusBadge
                      status={
                        item.status
                      }
                    />
                  </td>

                  <td>

                    {item.status ===
                      "pending" && (

                      <div className="action-buttons">

                        <button
                          className="approve-btn"
                          disabled={
                            busyId ===
                            item.id
                          }
                          onClick={() =>
                            processWithdrawal(
                              item.id,
                              "approved"
                            )
                          }
                        >
                          Approve
                        </button>

                        <button
                          className="reject-btn"
                          disabled={
                            busyId ===
                            item.id
                          }
                          onClick={() =>
                            processWithdrawal(
                              item.id,
                              "rejected"
                            )
                          }
                        >
                          Reject
                        </button>

                      </div>

                    )}

                  </td>

                </tr>

              ))}

            </tbody>

          </table>

        </div>

      </section>

    </PageContainer>
  );
}

/* =========================================================
   TRANSACTIONS PAGE
   ========================================================= */

function TransactionsPage({
  transactions,
}) {
  return (
    <PageContainer
      title="Transactions"
      subtitle="Financial activity across ZenexPay."
    >

      <section className="panel">

        <div className="data-table-wrap">

          <table className="modern-table">

            <thead>
              <tr>
                <th>User</th>
                <th>Amount</th>
                <th>Type</th>
                <th>Status</th>
                <th>Date</th>
              </tr>
            </thead>

            <tbody>

              {transactions.map(
                item => (

                  <tr key={item.id}>

                    <td>
                      {shortId(
                        item.user_id
                      )}
                    </td>

                    <td className="money">
                      {money(
                        item.amount
                      )}
                    </td>

                    <td>
                      {item.type ||
                        "-"}
                    </td>

                    <td>
                      <StatusBadge
                        status={
                          item.status ||
                          "completed"
                        }
                      />
                    </td>

                    <td>
                      {dateText(
                        item.created_at
                      )}
                    </td>

                  </tr>

                )
              )}

            </tbody>

          </table>

        </div>

      </section>

    </PageContainer>
  );
}

/* =========================================================
   PAGE CONTAINER
   ========================================================= */

function PageContainer({
  title,
  subtitle,
  children,
}) {
  return (
    <div className="content">

      <div className="page-heading">

        <div>
          <h1>{title}</h1>
          <p>{subtitle}</p>
        </div>

      </div>

      {children}

    </div>
  );
}

/* =========================================================
   LOGIN
   ========================================================= */

function Login({
  onLogin,
}) {
  const [email, setEmail] =
    useState("");

  const [password, setPassword] =
    useState("");

  const [busy, setBusy] =
    useState(false);

  async function submit(e) {
    e.preventDefault();

    setBusy(true);

    try {
      await onLogin(
        email,
        password
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-screen">

      <div className="login-glow one" />
      <div className="login-glow two" />

      <div className="login-box">

        <div className="login-brand">

          <div className="brand-mark big">
            Z
          </div>

          <div>
            <div className="brand-name">
              Zenex<span>Pay</span>
            </div>

            <div className="brand-sub">
              ADMIN PANEL
            </div>
          </div>

        </div>

        <h1>
          Welcome back
        </h1>

        <p>
          Sign in to manage your
          ZenexPay platform.
        </p>

        <form onSubmit={submit}>

          <label>
            Email
          </label>

          <input
            type="email"
            value={email}
            onChange={e =>
              setEmail(
                e.target.value
              )
            }
            placeholder="Admin email"
            required
          />

          <label>
            Password
          </label>

          <input
            type="password"
            value={password}
            onChange={e =>
              setPassword(
                e.target.value
              )
            }
            placeholder="Password"
            required
          />

          <button
            className="login-button"
            disabled={busy}
            type="submit"
          >
            {busy
              ? "Signing in..."
              : "Sign In →"}
          </button>

        </form>

        <div className="login-footer">
          <span>●</span>
          Secure Admin Access
        </div>

      </div>

    </div>
  );
}

createRoot(
  document.getElementById("root")
).render(
  <App />
);
