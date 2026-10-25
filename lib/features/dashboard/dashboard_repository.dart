import '../../core/api_client.dart';
import '../../core/session_store.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.summary,
    required this.details,
    required this.orderStatus,
    required this.rentalStatus,
    required this.recentPayments,
  });

  final Map<String, dynamic> summary;
  final Map<String, dynamic> details;
  final Map<String, dynamic> orderStatus;
  final Map<String, dynamic> rentalStatus;
  final List<Object?> recentPayments;

  int? get totalCustomers => _readCount(summary['totalCustomers']);
  int? get totalOrders => _readCount(summary['totalOrders']);
  int? get ordersToday => _readCount(summary['ordersToday']);
  int? get pendingOrders => _readCount(summary['pendingOrders']);
  int? get deliveredOrders => _readCount(summary['totalDeliveredOrders']);
  int? get rentalsDueToday => _readCount(details['rentalsDueToday']);
  int? get overdueRentals => _readCount(details['overdueRentals']);

  List<DashboardStatusCount> get tailoringStatuses =>
      _statusCounts(orderStatus);
  List<DashboardStatusCount> get rentalStatuses => _statusCounts(
    rentalStatus,
    fallbackLabels: const ['Booked', 'Delivered', 'In alterations', 'Returns'],
  );

  static List<DashboardStatusCount> _statusCounts(
    Map<String, dynamic> status, {
    List<String> fallbackLabels = const [],
  }) {
    final labels = status['labels'];
    final series = status['series'];
    if (labels is List && labels.isNotEmpty) {
      return [
        for (var index = 0; index < labels.length; index++)
          if (labels[index].toString().trim().isNotEmpty)
            DashboardStatusCount(
              label: labels[index].toString(),
              count: series is List && index < series.length
                  ? _readCount(series[index])
                  : null,
            ),
      ];
    }
    return [
      for (final label in fallbackLabels) DashboardStatusCount(label: label),
    ];
  }

  static int? _readCount(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is List) return value.length;
    return null;
  }
}

class DashboardStatusCount {
  const DashboardStatusCount({required this.label, this.count});

  final String label;
  final int? count;
}

class DashboardRepository {
  const DashboardRepository(this._api);

  final ApiClient _api;

  Future<DashboardSnapshot> load(AuthSession session) async {
    _api.token = session.token;
    final responses = await Future.wait<Map<String, dynamic>>([
      _api.get('Transaction/GetDashboardSummaryAsync'),
      _api.get('transaction/GetDashboardDetails'),
      _api.get('transaction/GetOrderAndRentalStatusCounts'),
      _api.post('Transaction/GetRecentPaymentsAsync', const {}),
    ]);

    for (final response in responses) {
      if (response['errorCode'] != null && response['errorCode'] != 0) {
        throw ApiException(
          response['message']?.toString() ??
              response['errorDesc']?.toString() ??
              'Unable to load dashboard data.',
        );
      }
    }

    final details = _dataMap(responses[1]);
    final statuses = _dataMap(responses[2]);
    final payments = responses[3]['data'];

    return DashboardSnapshot(
      summary: _dataMap(responses[0]),
      details: details,
      orderStatus: _dataMap(statuses['orderStatus']),
      rentalStatus: _dataMap(statuses['rentalStatus']),
      recentPayments: payments is List ? payments : const [],
    );
  }

  Map<String, dynamic> _dataMap(Object? response) {
    if (response is! Map<String, dynamic>) return const {};
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    return response;
  }
}
