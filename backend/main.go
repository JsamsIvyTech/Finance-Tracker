package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq" // Supabase PostgreSQL Driver
	"golang.org/x/crypto/bcrypt"
)

// --- Models ---

type User struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Password string `json:"password"`
}

type Transaction struct {
	ID       string    `json:"id"`
	UserID   string    `json:"userId"`
	Title    string    `json:"title"`
	Amount   float64   `json:"amount"`
	Date     time.Time `json:"date"`
	Category string    `json:"category"`
}

type AuthRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type AuthResponse struct {
	Message string `json:"message"`
	UserID  string `json:"userId,omitempty"`
}

// Global Database Connection
var db *sql.DB

// --- Database Initialization ---

func initDB() {
	var err error
	connStr := os.Getenv("DATABASE_URL")
	if connStr == "" {
		log.Println("Warning: DATABASE_URL not set!")
	}

	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Failed to open Supabase Postgres connection: %v", err)
	}

	fmt.Println("Connected to Supabase PostgreSQL database!")
}

// --- CORS Middleware ---

func enableCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next(w, r)
	}
}

// --- Health Handler (Wakes up Python backend) ---

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Automatically wake up Python backend when Go is pinged by Cron-Job!
	if pythonURL := os.Getenv("PYTHON_BACKEND_URL"); pythonURL != "" {
		client := &http.Client{Timeout: 4 * time.Second}
		if resp, err := client.Get(pythonURL + "/api/analytics/health"); err == nil {
			resp.Body.Close()
		}
	}

	json.NewEncoder(w).Encode(map[string]string{"status": "alive"})
}

// --- Auth Handlers ---

func registerHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Method not allowed"})
		return
	}

	var req AuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Invalid request body"})
		return
	}

	if req.Username == "" || req.Password == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Username and password required"})
		return
	}

	// Check if username exists ($1 placeholder)
	var existingID string
	err := db.QueryRow("SELECT id FROM users WHERE username = $1", req.Username).Scan(&existingID)
	if err == nil {
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Username already exists"})
		return
	}

	// Hash password using bcrypt
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Failed to hash password"})
		return
	}

	userID := fmt.Sprintf("u_%d", time.Now().UnixNano())
	_, err = db.Exec("INSERT INTO users (id, username, password) VALUES ($1, $2, $3)", userID, req.Username, string(hashedPassword))
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Database Error: " + err.Error()})
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(AuthResponse{
		Message: "Registration successful!",
		UserID:  userID,
	})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Method not allowed"})
		return
	}

	var req AuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Invalid request body"})
		return
	}

	var user User
	err := db.QueryRow("SELECT id, username, password FROM users WHERE username = $1", req.Username).
		Scan(&user.ID, &user.Username, &user.Password)

	if err != nil || bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)) != nil {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Invalid username or password"})
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(AuthResponse{
		Message: "Login successful!",
		UserID:  user.ID,
	})
}

// --- Transaction Handlers ---

func transactionsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodGet:
		userID := r.URL.Query().Get("userId")
		if userID == "" {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "userId query parameter required"})
			return
		}

		rows, err := db.Query("SELECT id, user_id, title, amount, date, category FROM transactions WHERE user_id = $1", userID)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": "Database query error: " + err.Error()})
			return
		}
		defer rows.Close()

		userTxs := []Transaction{}
		for rows.Next() {
			var tx Transaction
			var dateStr string
			if err := rows.Scan(&tx.ID, &tx.UserID, &tx.Title, &tx.Amount, &dateStr, &tx.Category); err != nil {
				continue
			}
			tx.Date, _ = time.Parse(time.RFC3339, dateStr)
			if tx.Category == "" {
				tx.Category = "Other"
			}
			userTxs = append(userTxs, tx)
		}

		json.NewEncoder(w).Encode(userTxs)

	case http.MethodPost:
		var tx Transaction
		if err := json.NewDecoder(r.Body).Decode(&tx); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "Invalid request body"})
			return
		}

		if tx.UserID == "" || tx.Title == "" || tx.Amount <= 0 {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "userId, title, and amount required"})
			return
		}

		if tx.ID == "" {
			tx.ID = fmt.Sprintf("t_%d", time.Now().UnixNano())
		}
		if tx.Date.IsZero() {
			tx.Date = time.Now()
		}
		if tx.Category == "" {
			tx.Category = "Other"
		}

		_, err := db.Exec(
			"INSERT INTO transactions (id, user_id, title, amount, date, category) VALUES ($1, $2, $3, $4, $5, $6)",
			tx.ID, tx.UserID, tx.Title, tx.Amount, tx.Date.Format(time.RFC3339), tx.Category,
		)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": "Database insert error: " + err.Error()})
			return
		}

		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(tx)

	case http.MethodDelete:
		txID := r.URL.Query().Get("id")
		if txID == "" {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "id query parameter required"})
			return
		}

		_, err := db.Exec("DELETE FROM transactions WHERE id = $1", txID)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": "Database delete error: " + err.Error()})
			return
		}

		json.NewEncoder(w).Encode(map[string]string{"message": "Transaction deleted"})

	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(map[string]string{"error": "Method not allowed"})
	}
}

func main() {
	initDB()
	defer db.Close()

	http.HandleFunc("/api/health", enableCORS(healthHandler))
	http.HandleFunc("/api/register", enableCORS(registerHandler))
	http.HandleFunc("/api/login", enableCORS(loginHandler))
	http.HandleFunc("/api/transactions", enableCORS(transactionsHandler))

	port := ":8080"
	fmt.Printf("Server running on http://localhost%s...\n", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
