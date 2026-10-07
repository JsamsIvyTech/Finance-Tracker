import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(String) deleteTx;

  const TransactionList({
    super.key,
    required this.transactions,
    required this.deleteTx,
  });

  // Helper method to map Category String -> Icon
  IconData _getCategoryIcon(String category, bool isIncome) {
    if (isIncome) {
      switch (category) {
        case 'Salary':
          return Icons.work;
        case 'Gift':
          return Icons.card_giftcard;
        case 'Side Gig':
          return Icons.star;
        case 'Investment':
          return Icons.show_chart;
        default:
          return Icons.payments;
      }
    } else {
      switch (category) {
        case 'Food':
          return Icons.fastfood;
        case 'Rent':
          return Icons.home;
        case 'Transport':
          return Icons.directions_car;
        case 'Entertainment':
          return Icons.movie;
        case 'Shopping':
          return Icons.shopping_bag;
        case 'Bills':
          return Icons.receipt_long;
        default:
          return Icons.attach_money;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: transactions.isEmpty
          ? const Center(
              child: Text(
                'No transactions added yet!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (ctx, index) {
                final tx = transactions[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: tx.isIncome ? Colors.green.shade100 : Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        _getCategoryIcon(tx.category, tx.isIncome),
                        color: tx.isIncome ? Colors.green.shade800 : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      tx.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${tx.category} • ${DateFormat.yMMMd().format(tx.date)}'),
                    trailing: SizedBox(
                      width: 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${tx.isIncome ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: tx.isIncome ? Colors.green.shade800 : Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => deleteTx(tx.id),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
