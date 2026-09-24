import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/transaction.dart';
import 'screens/auth_screen.dart';
import 'services/api_service.dart';
import 'widgets/transaction_list.dart';
import 'widgets/new_transaction.dart';
import 'widgets/summary_card.dart';
import 'widgets/recurring_card.dart';
import 'widgets/prediction_card.dart'; // 1. Import PredictionCard

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BasicPage(),
    );
  }
}

class BasicPage extends StatefulWidget {
  const BasicPage({super.key});

  @override
  State<BasicPage> createState() => _BasicPageState();
}

class _BasicPageState extends State<BasicPage> {
  String? _userId;
  List<Transaction> _userTransactions = [];
  Map<String, dynamic>? _analyticsData;
  Map<String, dynamic>? _predictionData; // 2. State for AI prediction
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('userId');
    if (savedUserId != null) {
      setState(() {
        _userId = savedUserId;
      });
      _loadTransactions();
    }
  }

  Future<void> _saveLogin(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    setState(() {
      _userId = userId;
    });
    _loadTransactions();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    setState(() {
      _userId = null;
      _userTransactions = [];
      _analyticsData = null;
      _predictionData = null;
    });
  }

  double get _totalSpending {
    return _userTransactions.fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> _loadTransactions() async {
    if (_userId == null) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final txs = await ApiService.fetchTransactions(_userId!);
      setState(() {
        _userTransactions = txs;
      });
      _loadAnalytics();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load transactions from Go server.')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 3. Fetch Python Analytics & AI Forecast
  Future<void> _loadAnalytics() async {
    if (_userId == null) return;
    try {
      final data = await ApiService.fetchAnalytics(_userId!);
      final prediction = await ApiService.fetchPrediction(_userId!);
      setState(() {
        _analyticsData = data;
        _predictionData = prediction;
      });
    } catch (err) {
      // Ignore if Python analytics service is offline
    }
  }

  void _addNewTransaction(String txTitle, double txAmount, DateTime chosenDate, String txCategory) async {
    if (_userId == null) return;

    try {
      final newTx = await ApiService.addTransaction(_userId!, txTitle, txAmount, chosenDate, txCategory);
      setState(() {
        _userTransactions.add(newTx);
      });
      _loadAnalytics();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $err')),
        );
      }
    }
  }

  void _deleteTransaction(String id) async {
    try {
      await ApiService.deleteTransaction(id);
      setState(() {
        _userTransactions.removeWhere((tx) => tx.id == id);
      });
      _loadAnalytics();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete transaction.')),
        );
      }
    }
  }

  void _startAddNewTransaction(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) {
        return NewTransaction(addTx: _addNewTransaction);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return AuthScreen(
        onLoginSuccess: (userId) {
          _saveLogin(userId);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _startAddNewTransaction(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            SummaryCard(
              totalSpending: _totalSpending,
              transactionCount: _userTransactions.length,
            ),
            // Python AI Spending Forecast Card!
            PredictionCard(predictionData: _predictionData),
            // Python Subscription Insights Card!
            RecurringCard(analyticsData: _analyticsData),
            TransactionList(
              transactions: _userTransactions,
              deleteTx: _deleteTransaction,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _startAddNewTransaction(context),
      ),
    );
  }
}