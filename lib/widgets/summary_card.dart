import 'package:flutter/material.dart';
import '../models/transaction.dart';

class SummaryCard extends StatelessWidget {
  final List<Transaction> transactions;

  const SummaryCard({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate Earned Income vs Total Expenses
    final double totalIncome = transactions
        .where((tx) => tx.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);

    final double totalExpense = transactions
        .where((tx) => !tx.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);

    final double netRemaining = totalIncome - totalExpense;
    final bool isPositive = netRemaining >= 0;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Net Remaining Budget',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isPositive ? Colors.green.shade900 : Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${isPositive ? '+' : ''}\$${netRemaining.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Earned Income', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '+\$${totalIncome.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Total Expenses', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '-\$${totalExpense.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}