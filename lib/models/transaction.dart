class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.category = 'Other',
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        category: json['category'] ?? 'Other',
    );
  }

  Map<String, dynamic> toJson(String userId) {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
    };
  }
}