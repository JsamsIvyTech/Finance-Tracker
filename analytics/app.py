from flask import Flask, jsonify, request
from flask_cors import CORS
import sqlite3
import os
import re
from datetime import datetime, timedelta

app = Flask(__name__)
CORS(app) # Enable CORS

# Path to DB
# Replace line 13 in analytics/app.py with this:
if os.path.exists('/app/db'):
    DB_PATH = '/app/db/finance.db'
else:
    DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'backend', 'finance.db')

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

# Smart Date Parser Function
def extract_date_from_text(text_lower):
    now = datetime.now()

    # 1. Check "last month" or "X months ago"
    if "last month" in text_lower:
        prev_month = now.month - 1 if now.month > 1 else 12
        prev_year = now.year if now.month > 1 else now.year - 1
        return datetime(prev_year, prev_month, min(now.day, 28))

    months_ago_match = re.search(r'(\d+)\s*months?\s*ago', text_lower)
    if months_ago_match:
        m_count = int(months_ago_match.group(1))
        target_month = (now.month - m_count - 1) % 12 + 1
        target_year = now.year - ((now.month - m_count - 1) // 12)
        return datetime(target_year, target_month, min(now.day, 28))

    # 2. Check "yesterday", "last week", or "X days ago"
    if "yesterday" in text_lower:
        return now - timedelta(days=1)
    if "last week" in text_lower:
        return now - timedelta(days=7)

    days_ago_match = re.search(r'(\d+)\s*days?\s*ago', text_lower)
    if days_ago_match:
        days = int(days_ago_match.group(1))
        return now - timedelta(days=days)

    # 3. Check specific month names (e.g. "august 15", "15th of august")
    month_names = {
        "january": 1, "jan": 1, "february": 2, "feb": 2, "march": 3, "mar": 3,
        "april": 4, "apr": 4, "may": 5, "june": 6, "jun": 6, "july": 7, "jul": 7,
        "august": 8, "aug": 8, "september": 9, "sep": 9, "sept": 9, "october": 10,
        "oct": 10, "november": 11, "nov": 11, "december": 12, "dec": 12
    }

    for month_name, month_num in month_names.items():
        if month_name in text_lower:
            # Look for day number near month name
            day_match = re.search(r'\b(\d{1,2})(st|nd|rd|th)?\b', text_lower)
            day_val = int(day_match.group(1)) if day_match and int(day_match.group(1)) <= 31 else 1
            year_val = now.year if month_num <= now.month else now.year - 1
            try:
                return datetime(year_val, month_num, day_val)
            except ValueError:
                pass

    # 4. Check explicit date formats like '09/17/2026' or '9/17'
    date_slash_match = re.search(r'\b(\d{1,2})[/.\-](\d{1,2})(?:[/.\-](\d{2,4}))?\b', text_lower)
    if date_slash_match:
        m = int(date_slash_match.group(1))
        d = int(date_slash_match.group(2))
        y = int(date_slash_match.group(3)) if date_slash_match.group(3) else now.year
        if y < 100:
            y += 2000
        try:
            return datetime(y, m, d)
        except ValueError:
            pass

    # 5. Check "first of the month" / "1st"
    if "first of" in text_lower or "1st of" in text_lower or "beginning of" in text_lower:
        return datetime(now.year, now.month, 1)

    # 6. Check ordinal days like "17th", "17th of the month"
    ordinal_day_match = re.search(r'\b(\d{1,2})(st|nd|rd|th)?\s*(of\s*(the\s*)?month)?\b', text_lower)
    if ordinal_day_match:
        day_num = int(ordinal_day_match.group(1))
        if 1 <= day_num <= 31:
            try:
                return datetime(now.year, now.month, day_num)
            except ValueError:
                pass

    return now

@app.route('/api/analytics/health', methods=['GET'])
def health_check():
    return jsonify({"status": "Python Analytics Service is running!"})

@app.route('/api/analytics/recurring', methods=['GET'])
def detect_recurring():
    user_id = request.args.get('userId')
    if not user_id:
        return jsonify({"error": "userId is required"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, title, amount, date FROM transactions WHERE user_id = ?", (user_id,))
    rows = cursor.fetchall()
    conn.close()

    title_summary = {}
    for row in rows:
        title = row['title'].strip().title()
        amount = row['amount']

        if title not in title_summary:
            title_summary[title] = {"count": 0, "total_amount": 0.0, "last_amount": amount}

        title_summary[title]["count"] += 1
        title_summary[title]["total_amount"] += amount

    recurring_items = []
    total_recurring_monthly = 0.0

    for title, info in title_summary.items():
        if info["count"] >= 2:
            recurring_items.append({
                "title": title,
                "amount": info["total_amount"],
                "frequency": f"Repeated {info['count']} times"
            })
            total_recurring_monthly += info["total_amount"]

    return jsonify({
        "userId": user_id,
        "totalRecurringMonthly": total_recurring_monthly,
        "recurringCount": len(recurring_items),
        "recurringTransactions": recurring_items,
        "insightMessage": f"You spend ${total_recurring_monthly:.2f}/mo on {len(recurring_items)} recurring bills." if recurring_items else "No recurring subscriptions detected yet."
    })

@app.route('/api/analytics/predict', methods=['GET'])
def predict_spending():
    user_id = request.args.get('userId')
    if not user_id:
        return jsonify({"error": "userId is required"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT amount, date FROM transactions WHERE user_id = ?", (user_id,))
    rows = cursor.fetchall()
    conn.close()

    if not rows:
        return jsonify({
            "userId": user_id,
            "predictedNextMonth": 0.0,
            "predictionMessage": "Add a few transactions to unlock your next-month AI spending forecast!",
            "recommendation": "Keep track of your expense daily for accurate forecasts.",
        })

    total_spent = sum(row['amount'] for row in rows)
    predicted_next_month = round(total_spent * 1.05, 2)
    potential_savings = round(predicted_next_month * 0.15, 2)

    return jsonify({
        "userId": user_id,
        "predictedNextMonth": predicted_next_month,
        "potentialSavings": potential_savings,
        "predictionMessage": f"Based on your trends, your predicted spending for next month is ${predicted_next_month:.2f} next month!",
        "recommendation": f"AI TIP: Cutting unneeded recurring expenses could save you up to ${potential_savings:.2f} next month!",
    })

@app.route('/api/analytics/parse-receipt', methods=['POST'])
def parse_receipt():
    data = request.get_json() or {}
    raw_text = data.get('text', '').strip()

    if not raw_text:
        return jsonify({"error": "No text provided"}), 400

    text_lower = raw_text.lower()

    # 1. Smart Amount Extraction (prioritizes '$' or decimals like $5.75 or 42.99)
    amount = 0.0
    dollar_match = re.search(r'\$\s*(\d+(\.\d{1,2})?)', raw_text)
    decimal_match = re.search(r'\b(\d+\.\d{1,2})\b', raw_text)
    any_num_match = re.search(r'\b(\d+)\b', raw_text)

    if dollar_match:
        amount = float(dollar_match.group(1))
    elif decimal_match:
        amount = float(decimal_match.group(1))
    elif any_num_match:
        amount = float(any_num_match.group(1))

    # 2. Extract Category
    category = "Other"
    if any(k in text_lower for k in ["coffee", "starbucks", "mcdonalds", "food", "dinner", "lunch", "groceries", "restaurant"]):
        category = "Food"
    elif any(k in text_lower for k in ["uber", "lyft", "gas", "shell", "parking", "car", "transit"]):
        category = "Transport"
    elif any(k in text_lower for k in ["netflix", "cinema", "movie", "steam", "game", "spotify"]):
        category = "Entertainment"
    elif any(k in text_lower for k in ["walmart", "target", "amazon", "clothes", "store"]):
        category = "Shopping"
    elif any(k in text_lower for k in ["electric", "water", "bill", "power", "internet"]):
        category = "Bills"
    elif any(k in text_lower for k in ["rent", "lease"]):
        category = "Rent"

    # 3. Extract Date using Smart Date Parser
    date_obj = extract_date_from_text(text_lower)

    # 4. Clean Merchant Title (strips amounts, dates, month names, and filler/action words)
    clean_title = raw_text
    if dollar_match:
        clean_title = clean_title.replace(dollar_match.group(0), '')
    elif decimal_match:
        clean_title = clean_title.replace(decimal_match.group(0), '')

    # Strip explicit date patterns like 09/17/2026 or 9/17
    clean_title = re.sub(r'\b(\d{1,2})[/.\-](\d{1,2})(?:[/.\-](\d{2,4}))?\b', '', clean_title)

    # Strip month names and date words
    clean_title = re.sub(r'\b(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)\b', '', clean_title, flags=re.IGNORECASE)
    clean_title = re.sub(r'\b(\d{1,2})(st|nd|rd|th)\b', '', clean_title, flags=re.IGNORECASE)

    # Strip action & filler words (spent, spen, paid, cost, dollars, bucks, in, on, for, i, my)
    clean_title = re.sub(r'\b(yesterday|today|tomorrow|last month|last week|first|beginning|end|days?\s*ago|months?\s*ago|of\s*the\s*month|the\s*month|on\s*the|for|at|in|on|i|my|spen|spent|spend|paid|cost|dollars?|bucks?)\b', '', clean_title, flags=re.IGNORECASE)

    clean_title = re.sub(r'\s+', ' ', clean_title).strip()
    title = clean_title.title() if clean_title else "Quick Expense"

    return jsonify({
        "title": title,
        "amount": amount,
        "category": category,
        "date": date_obj.strftime("%Y-%m-%dT%H:%M:%SZ")
    })

if __name__ == '__main__':
    print("Python Analytics Service is starting on http://localhost:5000...")
    app.run(host='0.0.0.0', port=5000, debug=True)