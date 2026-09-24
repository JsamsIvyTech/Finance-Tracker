import 'models/transaction.dart';

final List<Transaction> dummyTransactions = [
  Transaction(
    id: 't1',
    title: 'New Shoes',
    amount: 69.99,
    date: DateTime.now(),
  ),
  Transaction(
    id: 't2',
    title: 'Weekly Groceries',
    amount: 150.00,
    date: DateTime.now().subtract(const Duration(days: 5)),
  ),
];
