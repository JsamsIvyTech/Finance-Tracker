import 'package:flutter/material.dart';

class PredictionCard extends StatelessWidget {
  final Map<String, dynamic>? predictionData;

  const PredictionCard({super.key, required this.predictionData});

  @override
  Widget build(BuildContext context) {
    if (predictionData == null) {
      return const SizedBox.shrink();
    }

    final double predictedNextMonth = (predictionData!['predictedNextMonth'] as num?)?.toDouble() ?? 0.0;
    final String predictionMessage = predictionData!['predictionMessage'] ?? '';
    final String recommendation = predictionData!['recommendation'] ?? '';

    if (predictedNextMonth == 0.0) {
      return const SizedBox.shrink(); // Don't show if no predictions yet
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Python AI Spending Forecast',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              predictionMessage,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                recommendation,
                style: TextStyle(fontSize: 13, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}