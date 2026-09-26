import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';

class ApiService {
  // Go REST Backend Cloud Base URL
  static String get baseUrl => 'https://finance-go-backend.onrender.com/api';

  // Register user with 40s timeout for cloud cold starts
  static Future<Map<String, dynamic>> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 40));
    return jsonDecode(response.body);
  }

  // Login user with 40s timeout for cloud cold starts
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 40));
    return jsonDecode(response.body);
  }

  // Fetch transactions from Go server
  static Future<List<Transaction>> fetchTransactions(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions?userId=$userId'),
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Transaction.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  // Add new transaction to Go server
  static Future<Transaction> addTransaction(
      String userId,
      String title,
      double amount,
      DateTime date,
      String category,
      ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'title': title,
        'amount': amount,
        'date': date.toUtc().toIso8601String(),
        'category': category,
      }),
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode == 201) {
      return Transaction.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Status ${response.statusCode}: ${response.body}');
    }
  }

  // Delete transaction from Go server
  static Future<void> deleteTransaction(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/transactions?id=$id'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete transaction');
    }
  }

  // Python analytics service base url
  static String get analyticsBaseUrl => 'https://finance-python-analytics.onrender.com/api/analytics';

  // fetch python analytics
  static Future<Map<String, dynamic>> fetchAnalytics(String userId) async {
    final response = await http.get(
      Uri.parse('$analyticsBaseUrl/recurring?userId=$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load analytics');
    }
  }

  static Future<Map<String, dynamic>> fetchPrediction(String userId) async {
    final response = await http.get(
      Uri.parse('$analyticsBaseUrl/predict?userId=$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load spending prediction');
    }
  }

  static Future<Map<String, dynamic>> parseReceiptText(String rawText) async {
    final response = await http.post(
      Uri.parse('$analyticsBaseUrl/parse-receipt'),
      headers: {'Content-Type': "application/json"},
      body: jsonEncode({'text': rawText}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to parse receipt text');
    }
  }
}
