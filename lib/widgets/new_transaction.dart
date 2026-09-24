import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class NewTransaction extends StatefulWidget {
  final Function(String, double, DateTime, String) addTx;

  const NewTransaction({super.key, required this.addTx});

  @override
  State<NewTransaction> createState() => _NewTransactionState();
}

class _NewTransactionState extends State<NewTransaction> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _quickTextController = TextEditingController(); // Controller for AI Quick Fill
  DateTime? _selectedDate;
  bool _isParsing = false;

  final List<String> _categories = [
    'Food',
    'Rent',
    'Transport',
    'Entertainment',
    'Shopping',
    'Bills',
    'Other'
  ];
  String _selectedCategory = 'Food';

  // Call Python AI Parser Endpoint
  Future<void> _parseWithAI() async {
    final rawText = _quickTextController.text.trim();
    if (rawText.isEmpty) return;

    setState(() {
      _isParsing = true;
    });

    try {
      final parsed = await ApiService.parseReceiptText(rawText);

      setState(() {
        if (parsed['title'] != null && parsed['title'].toString().isNotEmpty) {
          _titleController.text = parsed['title'];
        }
        if (parsed['amount'] != null && parsed['amount'] > 0) {
          _amountController.text = parsed['amount'].toString();
        }
        if (parsed['category'] != null && _categories.contains(parsed['category'])) {
          _selectedCategory = parsed['category'];
        }
        if (parsed['date'] != null) {
          _selectedDate = DateTime.parse(parsed['date']);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ AI Parsed: ${parsed['title']} (\$${parsed['amount']}) [${parsed['category']}]'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to parse with Python AI service.')),
        );
      }
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() {
        _selectedDate = pickedDate;
      });
    });
  }

  void _submitData() {
    final enteredTitle = _titleController.text;
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (enteredTitle.isEmpty || enteredAmount <= 0) {
      return;
    }

    widget.addTx(
      enteredTitle,
      enteredAmount,
      _selectedDate ?? DateTime.now(),
      _selectedCategory,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // --- AI Quick Fill Box ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _quickTextController,
                      decoration: const InputDecoration(
                        labelText: '✨ AI Quick Fill (Receipt / Messy Text)',
                        hintText: 'e.g. "Starbucks coffee \$5.75 yesterday"',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isParsing
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                      onPressed: _parseWithAI,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Parse with Python AI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // --- Manual / Parsed Fields ---
              TextField(
                decoration: const InputDecoration(labelText: 'Title'),
                controller: _titleController,
                onSubmitted: (_) => _submitData(),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Amount'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => _submitData(),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? 'No Date Chosen!'
                          : 'Picked Date: ${DateFormat.yMMMd().format(_selectedDate!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _presentDatePicker,
                    child: const Text(
                      'Choose Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _submitData,
                child: const Text('Add Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}