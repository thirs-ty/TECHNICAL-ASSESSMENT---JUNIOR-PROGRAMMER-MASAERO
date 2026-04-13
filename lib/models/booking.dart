class Booking {
  final String id;
  final String customerName;
  final String serviceType;
  final double amount;
  String status;
  bool discountApplied;

  Booking({
    required this.id,
    required this.customerName,
    required this.serviceType,
    required this.amount,
    this.status = 'Pending',
    this.discountApplied = false,
  });

  bool get eligibleForDiscount => amount > 200;
  double get finalAmount => discountApplied ? amount * 0.9 : amount;
  double get discountSaving => amount - finalAmount;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id']?.toString() ?? '',
      customerName: json['customerName'] ?? 'Customer',
      serviceType: json['serviceType'] ?? 'General Service',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'Pending',
      discountApplied: json['discountApplied'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'customerName': customerName,
    'serviceType': serviceType,
    'amount': amount,
    'status': status,
    'discountApplied': discountApplied,
  };
}