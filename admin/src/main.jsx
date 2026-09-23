import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { createClient } from "@supabase/supabase-js";
import "./style.css";

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

const VERSION = "ZenexPay Admin v2.1";

const money = (value) => {
  const number = Number(value || 0);
  return `৳ ${number.toFixed(2)}`;
};

const formatDate = (value) => {
  if (!value) return "-";

  try {
    return new Date(value).toLocaleString();
  } catch {
    return String(value);
  }
};

async function fetchTable(table) {
  const { data, error } = await supabase
    .from(table)
    .select("*");

  if (error) {
    throw new Error(`${table}: ${error.message}`);
  }

  return data || [];
}

function App() {
  const [session, setSession] = useState(null);
  const [checkingSession, setCheckingSession] = useState(true);

  const [refreshing, setRefreshing] = useState(false);
  const [savingTask, setSavingTask] = useState(false);

  const [users, setUsers] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [submissions, setSubmissions] = useState([]);
  const [withdrawals, setWithdrawals] = useState([]);
  const [transactions, setTransactions] = useState([]);

  const [taskTitle, setTaskTitle] = useState("");
  const [taskDescription, setTaskDescription] = useState("");
  const [taskReward, setTaskReward] = useState("");
  const [taskType, setTaskType] = useState("general");

  useEffect(() => {
    checkSession();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
    });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (session) {
      loadData();
    }
  }, [session]);

  async function checkSession() {
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      setSession(session);
    } catch (error) {
      console.error("Session error:", error);
    } finally {
      setCheckingSession(false);
    }
  }

  async function login(email, password) {
    const { error } = await supabase.auth.signInWithPassword({
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

  async function loadData() {
    if (!session) return;

    setRefreshing(true);

    const errors = [];

    try {
      const data = await fetchTable("profiles");
      setUsers(data);
    } catch (error) {
      console.error(error);
      errors.push(`Users → ${error.message}`);
    }

    try {
      const data = await fetchTable("tasks");
      setTasks(data);
    } catch (error) {
      console.error(error);
      errors.push(`Tasks → ${error.message}`);
    }

    try {
      const data = await fetchTable("task_submissions");
      setSubmissions(data);
    } catch (error) {
      console.error(error);
      errors.push(`Submissions → ${error.message}`);
    }

    try {
      const data = await fetchTable("withdrawals");
      setWithdrawals(data);
    } catch (error) {
      console.error(error);
      errors.push(`Withdrawals → ${error.message}`);
    }

    try {
      const data = await fetchTable("transactions");
      setTransactions(data);
    } catch (error) {
      console.error(error);
      errors.push(`Transactions → ${error.message}`);
    }

    setRefreshing(false);

    if (errors.length > 0) {
      alert(
        "Refresh finished with errors:\n\n" +
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
      alert("Enter a valid task reward.");
      return;
    }

    setSavingTask(true);

    try {
      const payload = {
        title,
        description,
        reward,
        type: taskType,
      };

      const { error } = await supabase
        .from("tasks")
        .insert(payload);

      if (error) {
        throw error;
      }

      alert("Task added successfully.");

      setTaskTitle("");
      setTaskDescription("");
      setTaskReward("");
      setTaskType("general");

      await loadData();
    } catch (error) {
      console.error("Add task error:", error);

      alert(
        "Add Task failed:\n\n" +
          error.message
      );
    } finally {
      setSavingTask(false);
    }
  }

  async function approveSubmission(id) {
    if (!id) return;

    const confirmed = window.confirm(
      "Are you sure you want to approve this submission?"
    );

    if (!confirmed) return;

    const { error } = await supabase.rpc(
      "approve_submission",
      {
        p_submission_id: id,
      }
    );

    if (error) {
      console.error(error);

      alert(
        "Approve failed:\n\n" +
          error.message
      );

      return;
    }

    alert("Submission approved.");

    await loadData();
  }

  async function rejectSubmission(id) {
    if (!id) return;

    const reason = window.prompt(
      "Enter rejection reason:"
    );

    if (reason === null) {
      return;
    }

    const { error } = await supabase
      .from("task_submissions")
      .update({
        status: "rejected",
        rejection_reason: reason.trim(),
        reviewed_at: new Date().toISOString(),
        reviewed_by: session.user.id,
      })
      .eq("id", id);

    if (error) {
      console.error(error);

      alert(
        "Reject failed:\n\n" +
          error.message
      );

      return;
    }

    alert("Submission rejected.");

    await loadData();
  }

  async function processWithdrawal(id, status) {
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

    const { error } = await supabase.rpc(
      "process_withdrawal",
      {
        p_withdrawal_id: id,
        p_status: status,
        p_note: note,
      }
    );

    if (error) {
      console.error(error);

      alert(
        "Withdrawal update failed:\n\n" +
          error.message
      );

      return;
    }

    alert(
      status === "approved"
        ? "Withdrawal approved."
        : "Withdrawal rejected."
    );

    await loadData();
  }

  if (checkingSession) {
    return (
      <div className="app">
        <div className="card">
          <h2>Loading...</h2>
        </div>
      </div>
    );
  }

  if (!session) {
    return <Login onLogin={login} />;
  }

  return (
    <div className="app">

      <header className="topbar">

        <div>
          <h1>ZenexPay Admin</h1>
          <p>{VERSION}</p>
        </div>

        <div className="top-actions">

          <button
            onClick={loadData}
            disabled={refreshing}
          >
            {refreshing
              ? "Refreshing..."
              : "Refresh"}
          </button>

          <button onClick={logout}>
            Logout
          </button>

        </div>

      </header>

      <main className="container">

        {/* STATS */}

        <section className="stats">

          <div className="card">
            <h3>Users</h3>
            <strong>{users.length}</strong>
          </div>

          <div className="card">
            <h3>Tasks</h3>
            <strong>{tasks.length}</strong>
          </div>

          <div className="card">
            <h3>Submissions</h3>
            <strong>{submissions.length}</strong>
          </div>

          <div className="card">
            <h3>Withdrawals</h3>
            <strong>{withdrawals.length}</strong>
          </div>

        </section>

        {/* ADD TASK */}

        <section className="card">

          <h2>Add Task</h2>

          <div className="form-grid">

            <input
              value={taskTitle}
              onChange={(e) =>
                setTaskTitle(e.target.value)
              }
              placeholder="Task title"
            />

            <input
              value={taskDescription}
              onChange={(e) =>
                setTaskDescription(e.target.value)
              }
              placeholder="Task description"
            />

            <input
              value={taskReward}
              onChange={(e) =>
                setTaskReward(e.target.value)
              }
              placeholder="Reward"
              type="number"
              min="0"
              step="0.01"
            />

            <select
              value={taskType}
              onChange={(e) =>
                setTaskType(e.target.value)
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

            <button
              onClick={addTask}
              disabled={savingTask}
            >
              {savingTask
                ? "Saving..."
                : "Add Task"}
            </button>

          </div>

        </section>

        {/* TASKS */}

        <section className="card">

          <h2>Tasks</h2>

          {tasks.length === 0 ? (
            <p>No tasks found.</p>
          ) : (

            <div className="table-wrap">

              <table>

                <thead>
                  <tr>
                    <th>Title</th>
                    <th>Type</th>
                    <th>Reward</th>
                    <th>Status</th>
                  </tr>
                </thead>

                <tbody>

                  {tasks.map((task) => (

                    <tr key={task.id}>

                      <td>
                        {task.title || "-"}
                      </td>

                      <td>
                        {task.type || "-"}
                      </td>

                      <td>
                        {money(task.reward)}
                      </td>

                      <td>
                        {task.status || "-"}
                      </td>

                    </tr>

                  ))}

                </tbody>

              </table>

            </div>

          )}

        </section>

        {/* SUBMISSIONS */}

        <section className="card">

          <h2>Submissions</h2>

          {submissions.length === 0 ? (
            <p>No submissions found.</p>
          ) : (

            <div className="table-wrap">

              <table>

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

                  {submissions.map((item) => (

                    <tr key={item.id}>

                      <td>
                        {item.user_id || "-"}
                      </td>

                      <td>
                        {item.task_id || "-"}
                      </td>

                      <td>
                        {item.proof_text || "-"}
                      </td>

                      <td>
                        {item.status || "-"}
                      </td>

                      <td>

                        {item.status === "pending" && (

                          <>

                            <button
                              onClick={() =>
                                approveSubmission(
                                  item.id
                                )
                              }
                            >
                              Approve
                            </button>

                            <button
                              onClick={() =>
                                rejectSubmission(
                                  item.id
                                )
                              }
                            >
                              Reject
                            </button>

                          </>

                        )}

                      </td>

                    </tr>

                  ))}

                </tbody>

              </table>

            </div>

          )}

        </section>

        {/* WITHDRAWALS */}

        <section className="card">

          <h2>Withdrawals</h2>

          {withdrawals.length === 0 ? (
            <p>No withdrawals found.</p>
          ) : (

            <div className="table-wrap">

              <table>

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

                  {withdrawals.map((item) => (

                    <tr key={item.id}>

                      <td>
                        {item.user_id || "-"}
                      </td>

                      <td>
                        {money(item.amount)}
                      </td>

                      <td>
                        {item.method || "-"}
                      </td>

                      <td>
                        {item.account_number || "-"}
                      </td>

                      <td>
                        {item.status || "-"}
                      </td>

                      <td>

                        {item.status === "pending" && (

                          <>

                            <button
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
                              onClick={() =>
                                processWithdrawal(
                                  item.id,
                                  "rejected"
                                )
                              }
                            >
                              Reject
                            </button>

                          </>

                        )}

                      </td>

                    </tr>

                  ))}

                </tbody>

              </table>

            </div>

          )}

        </section>

        {/* USERS */}

        <section className="card">

          <h2>Users</h2>

          {users.length === 0 ? (
            <p>No users found.</p>
          ) : (

            <div className="table-wrap">

              <table>

                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Phone</th>
                    <th>Status</th>
                    <th>Created</th>
                  </tr>
                </thead>

                <tbody>

                  {users.map((user) => (

                    <tr key={user.id}>

                      <td>
                        {user.full_name || "-"}
                      </td>

                      <td>
                        {user.phone || "-"}
                      </td>

                      <td>
                        {user.status || "-"}
                      </td>

                      <td>
                        {formatDate(
                          user.created_at
                        )}
                      </td>

                    </tr>

                  ))}

                </tbody>

              </table>

            </div>

          )}

        </section>

        {/* TRANSACTIONS */}

        <section className="card">

          <h2>Transactions</h2>

          {transactions.length === 0 ? (
            <p>No transactions found.</p>
          ) : (

            <div className="table-wrap">

              <table>

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

                  {transactions.map((item) => (

                    <tr key={item.id}>

                      <td>
                        {item.user_id || "-"}
                      </td>

                      <td>
                        {money(item.amount)}
                      </td>

                      <td>
                        {item.type || "-"}
                      </td>

                      <td>
                        {item.status || "-"}
                      </td>

                      <td>
                        {formatDate(
                          item.created_at
                        )}
                      </td>

                    </tr>

                  ))}

                </tbody>

              </table>

            </div>

          )}

        </section>

      </main>

    </div>
  );
}

function Login({ onLogin }) {

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e) {

    e.preventDefault();

    setBusy(true);

    try {
      await onLogin(email, password);
    } finally {
      setBusy(false);
    }

  }

  return (

    <div className="app">

      <div className="login-card card">

        <h1>ZenexPay Admin</h1>

        <p>Admin Login</p>

        <form onSubmit={submit}>

          <input
            type="email"
            placeholder="Admin email"
            value={email}
            onChange={(e) =>
              setEmail(e.target.value)
            }
            required
          />

          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) =>
              setPassword(e.target.value)
            }
            required
          />

          <button
            type="submit"
            disabled={busy}
          >
            {busy
              ? "Logging in..."
              : "Login"}
          </button>

        </form>

      </div>

    </div>

  );
}

createRoot(
  document.getElementById("root")
).render(
  <App />
);
