import 'package:flutter/material.dart';

class RecurringCard extends StatelessWidget {
  final Map<String, dynamic>? analyticsData;

  const RecurringCard({super.key, required this.analyticsData});

  @override
  Widget build(BuildContext context) {
    if (analyticsData == null) {
      return const SizedBox.shrink();
    }

    final double totalMonthly = (analyticsData!['totalRecurringMonthly'] as num?)?.toDouble() ?? 0.0;
    final int recurringCount = analyticsData!['recurringCount'] ?? 0;
    final String insightMessage = analyticsData!['insightMessage'] ?? '';
    final List<dynamic> recurringList = analyticsData!['recurringTransactions'] ?? [];

    if (recurringCount == 0) {
      return const SizedBox.shrink(); // Hide if no recurring subscriptions detected yet
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_graph, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Python AI Insights: Subscriptions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insightMessage,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: recurringList.map((item) {
                return Chip(
                  avatar: const Icon(Icons.repeat, size: 16, color: Colors.purple),
                  label: Text('${item['title']}: \$${item['amount']}'),
                  backgroundColor: Colors.purple.shade100,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}