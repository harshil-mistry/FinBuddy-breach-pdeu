import '../models/shared_expense_model.dart';

class SettlementTransfer {
  final String from; // uid of person who owes money
  final String to; // uid of person who should receive money
  final double amount;

  SettlementTransfer({
    required this.from,
    required this.to,
    required this.amount,
  });

  @override
  String toString() {
    return '$from owes $to ₹${amount.toStringAsFixed(2)}';
  }
}

class DebtSimplifier {
  /// Analyzes a list of expenses and returns the minimum number of transactions
  /// needed to settle all debts in the pool.
  static List<SettlementTransfer> calculateSettlements(
      List<SharedExpenseModel> expenses) {
    if (expenses.isEmpty) return [];

    // 1. Calculate the net balance of every person
    // Net balance = Total paid - Total owed
    // Positive means they are owed money (creditor)
    // Negative means they owe money (debtor)
    Map<String, double> balances = {};

    for (var expense in expenses) {
      // The person who paid getting credited
      balances[expense.paidBy] =
          (balances[expense.paidBy] ?? 0.0) + expense.amount;

      // Deduct exactly what each person owes
      for (var entry in expense.splits.entries) {
        String uid = entry.key;
        double owedAmount = entry.value;
        balances[uid] = (balances[uid] ?? 0.0) - owedAmount;
      }
    }

    // 2. Separate into debtors and creditors
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    // Small epsilon to deal with floating point inaccuracies
    const double epsilon = 0.01;

    for (var entry in balances.entries) {
      if (entry.value < -epsilon) {
        debtors.add(entry); // Debtors (negative balance)
      } else if (entry.value > epsilon) {
        creditors.add(entry); // Creditors (positive balance)
      }
    }

    // 3. Resolve using a Greedy Algorithm
    List<SettlementTransfer> transfers = [];

    int i = 0; // debtor index
    int j = 0; // creditor index

    while (i < debtors.length && j < creditors.length) {
      // Debtor owes `debt` amount (make it positive for calculation)
      double debt = -debtors[i].value;
      String debtorId = debtors[i].key;

      // Creditor receives `credit` amount
      double credit = creditors[j].value;
      String creditorId = creditors[j].key;

      // Determine the settlement amount (the minimum of what is owed vs what is expected)
      double amountToSettle = debt < credit ? debt : credit;

      transfers.add(SettlementTransfer(
        from: debtorId,
        to: creditorId,
        amount: amountToSettle,
      ));

      // Adjust remaining balances
      debt = debt - amountToSettle;
      credit = credit - amountToSettle;

      // Update the lists
      debtors[i] = MapEntry(debtorId, -debt);
      creditors[j] = MapEntry(creditorId, credit);

      // If fully settled (accounting for float precision), move to next
      if (debt < epsilon) {
        i++;
      }
      if (credit < epsilon) {
        j++;
      }
    }

    return transfers;
  }
}
