import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class NewTransaction extends StatefulWidget {
  final Function(String, double, DateTime, String, bool) addTx;

  const NewTransaction({super.key, required this.addTx});

  @override
  State<NewTransaction> createState() => _NewTransactionState();
}

class _NewTransactionState extends State<NewTransaction> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _quickTextController = TextEditingController();
  DateTime? _selectedDate;
  bool _isParsing = false;
  bool _isIncome = false; // false = Expense, true = Income

  // Expense Categories
  final List<String> _expenseCategories = [
    'Food',
    'Rent',
    'Transport',
    'Entertainment',
    'Shopping',
    'Bills',
    'Other'
  ];

  // Income Categories
  final List<String> _incomeCategories = [
    'Salary',
    'Gift',
    'Side Gig',
    'Investment',
    'Other'
  ];

  String _selectedCategory = 'Food';

  List<String> get _currentCategories => _isIncome ? _incomeCategories : _expenseCategories;

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
        if (parsed['category'] != null && _currentCategories.contains(parsed['category'])) {
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
      _isIncome, // Pass _isIncome boolean!
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Card(
        elevation: 5,
        child: Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // --- Expense vs Income Segmented Toggle ---
              Center(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_downward, color: Colors.red),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_upward, color: Colors.green),
                    ),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _isIncome = newSelection.first;
                      // Switch default category when toggling Income vs Expense
                      _selectedCategory = _isIncome ? 'Salary' : 'Food';
                    });
                  },
                ),
              ),
              const SizedBox(height: 15),

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
                decoration: InputDecoration(labelText: _isIncome ? 'Income Source / Title' : 'Expense Title'),
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
                items: _currentCategories.map((cat) {
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isIncome ? Colors.green : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isIncome ? 'Add Income' : 'Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
