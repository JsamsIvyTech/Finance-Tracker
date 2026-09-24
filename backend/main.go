package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

    "golang.org/x/crypto/bcrypt"
	_ "modernc.org/sqlite"
)

// --- Models ---

type User struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Password string `json:"password"`
}

type Transaction struct {
	ID     string    `json:"id"`
	UserID string    `json:"userId"`
	Title  string    `json:"title"`
	Amount float64   `json:"amount"`
	Date   time.Time `json:"date"`
	Category string `json:"category"`
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

     // Automatically use Docker volume /app/db/finance.db if running inside Docker!
     dbPath := "./finance.db"
     if _, err := os.Stat("/app/db"); err == nil {
     	dbPath = "/app/db/finance.db"
     }

     db, err = sql.Open("sqlite", dbPath)
     if err != nil {
     	log.Fatalf("Failed to open SQLite database: %v", err)
     }

	// Create Users Table
	createUsersTable := `
	CREATE TABLE IF NOT EXISTS users (
		id TEXT PRIMARY KEY,
		username TEXT UNIQUE NOT NULL,
		password TEXT NOT NULL
	);`
	_, err = db.Exec(createUsersTable)
	if err != nil {
		log.Fatalf("Failed to create users table: %v", err)
	}

	// Create Transactions Table
	createTxsTable := `
	CREATE TABLE IF NOT EXISTS transactions (
		id TEXT PRIMARY KEY,
		user_id TEXT NOT NULL,
		title TEXT NOT NULL,
		amount REAL NOT NULL,
		date TEXT NOT NULL,
		category TEXT DEFAULT 'Other'
	);`
	_, err = db.Exec(createTxsTable)
	if err != nil {
		log.Fatalf("Failed to create transactions table: %v", err)
	}

	fmt.Println("Connected to SQLite database (finance.db)!")
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

// --- Auth Handlers ---

func registerHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req AuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.Username == "" || req.Password == "" {
		http.Error(w, "Username and password required", http.StatusBadRequest)
		return
	}

	// Check if username exists in SQLite
	var existingID string
	err := db.QueryRow("SELECT id FROM users WHERE username = ?", req.Username).Scan(&existingID)
	if err == nil {
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(AuthResponse{Message: "Username already exists"})
		return
	}

	//hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, "Failed to hash password", http.StatusInternalServerError)
		return
	}

	userID := fmt.Sprintf("u_%d", time.Now().UnixNano())
	_, err = db.Exec("INSERT INTO users (id, username, password) VALUES (?, ?, ?)", userID, req.Username, string(hashedPassword))

	if err != nil {
		http.Error(w, "Failed to register user", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(AuthResponse{
		Message: "Registration successful!",
		UserID:  userID,
	})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req AuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Query user from SQLite
	var user User
	err := db.QueryRow("SELECT id, username, password FROM users WHERE username = ?", req.Username).
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
			http.Error(w, "userId query parameter required", http.StatusBadRequest)
			return
		}

		rows, err := db.Query("SELECT id, user_id, title, amount, date, category FROM transactions WHERE user_id = ?", userID)
		if err != nil {
			http.Error(w, "Failed to query transactions", http.StatusInternalServerError)
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
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}

		if tx.UserID == "" || tx.Title == "" || tx.Amount <= 0 {
			http.Error(w, "userId, title, and amount required", http.StatusBadRequest)
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

		// Insert transaction into SQLite
		_, err := db.Exec(
			"INSERT INTO transactions (id, user_id, title, amount, date, category) VALUES (?, ?, ?, ?, ?, ?)",
			tx.ID, tx.UserID, tx.Title, tx.Amount, tx.Date.Format(time.RFC3339), tx.Category,
		)
		if err != nil {
			http.Error(w, "Failed to save transaction to database", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(tx)

	case http.MethodDelete:
		txID := r.URL.Query().Get("id")
		if txID == "" {
			http.Error(w, "id query parameter required", http.StatusBadRequest)
			return
		}

		// Delete transaction from SQLite
		_, err := db.Exec("DELETE FROM transactions WHERE id = ?", txID)
		if err != nil {
			http.Error(w, "Failed to delete transaction", http.StatusInternalServerError)
			return
		}

		json.NewEncoder(w).Encode(map[string]string{"message": "Transaction deleted"})

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func main() {
	// Initialize SQLite Database
	initDB()
	defer db.Close()

	// Routes
	http.HandleFunc("/api/health", enableCORS(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "Go backend with SQLite is running!"})
	}))

	http.HandleFunc("/api/register", enableCORS(registerHandler))
	http.HandleFunc("/api/login", enableCORS(loginHandler))
	http.HandleFunc("/api/transactions", enableCORS(transactionsHandler))

	port := ":8080"
	fmt.Printf("Server running on http://localhost%s...\n", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}