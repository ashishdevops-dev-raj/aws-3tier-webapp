import axios from "axios";

const baseURL = process.env.REACT_APP_API_URL || "/api";

const api = axios.create({
  baseURL,
  timeout: 10000,
  headers: { "Content-Type": "application/json" },
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error("[API Error]", error.message);
    return Promise.reject(error);
  }
);

export default api;
