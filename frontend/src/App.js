import React, { useEffect, useState, useCallback } from "react";
import api from "./api/client";
import "./App.css";

function App() {
  const [users, setUsers] = useState([]);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [health, setHealth] = useState({ status: "checking..." });
  const [error, setError] = useState(null);

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { data } = await api.get("/users");
      setUsers(data.data || []);
    } catch (err) {
      setError(err.response?.data?.message || err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchHealth = useCallback(async () => {
    try {
      const { data } = await api.get("/health");
      setHealth(data);
    } catch (err) {
      setHealth({ status: "unhealthy", db: "disconnected" });
    }
  }, []);

  useEffect(() => {
    fetchHealth();
    fetchUsers();
  }, [fetchHealth, fetchUsers]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim() || !email.trim()) return;
    try {
      await api.post("/users", { name, email });
      setName("");
      setEmail("");
      fetchUsers();
    } catch (err) {
      setError(err.response?.data?.message || err.message);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Delete this user?")) return;
    try {
      await api.delete(`/users/${id}`);
      fetchUsers();
    } catch (err) {
      setError(err.response?.data?.message || err.message);
    }
  };

  return (
    <div className="app">
      <header className="header">
        <h1>AWS 3-Tier Web Application</h1>
        <p className="subtitle">
          React · Node.js · MySQL on AWS (EC2 · RDS · ALB · VPC)
        </p>
        <div className={`badge ${health.status === "healthy" ? "ok" : "bad"}`}>
          API: {health.status}
          {health.db && ` · DB: ${health.db}`}
        </div>
      </header>

      <main className="main">
        <section className="card">
          <h2>Add User</h2>
          <form onSubmit={handleSubmit} className="form">
            <input
              type="text"
              placeholder="Name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
            <input
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
            <button type="submit">Add</button>
          </form>
          {error && <div className="error">{error}</div>}
        </section>

        <section className="card">
          <h2>Users ({users.length})</h2>
          {loading ? (
            <p>Loading...</p>
          ) : users.length === 0 ? (
            <p className="empty">No users yet — add one above.</p>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Created</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td>{u.id}</td>
                    <td>{u.name}</td>
                    <td>{u.email}</td>
                    <td>{new Date(u.created_at).toLocaleString()}</td>
                    <td>
                      <button className="danger" onClick={() => handleDelete(u.id)}>
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>
      </main>

      <footer className="footer">
        Built with React · Express · MySQL · Docker · NGINX · Terraform · AWS
      </footer>
    </div>
  );
}

export default App;
