import 'package:ce_tailor_rentals/features/transactions/transaction_voucher_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('voucher viewer presents an order as a readable voucher', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTransactionVoucherDetails(
                context,
                title: 'Order ORD-100 details',
                voucher: {
                  'orderNo': 'ORD-100',
                  'status': 'In progress',
                  'deliveryDate': '2026-10-30',
                  'customerName': 'Alex Tailor',
                  'customerMobile': '9876543210',
                  'orderDetails': [
                    {
                      'itemName': 'Shirt',
                      'sizeName': 'M',
                      'netAmount': 1250,
                      'tailorRemarks': 'Hidden item detail',
                      'orderMeasurements': [
                        {'measurementName': 'Chest', 'measurementValue': 40},
                      ],
                    },
                  ],
                  'advancePaid': 500,
                  'totalAmount': 1250,
                  'internalNote': 'Hidden voucher detail',
                },
              ),
              child: const Text('View voucher'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('View voucher'));
    await tester.pumpAndSettle();

    expect(find.text('Order ORD-100 details'), findsOneWidget);
    expect(find.text('VOUCHER'), findsOneWidget);
    expect(find.text('ORD-100'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Delivery Date  30-10-2026'), findsOneWidget);
    expect(find.text('2026-10-30'), findsNothing);
    expect(find.text('CUSTOMER'), findsOneWidget);
    expect(find.text('Alex Tailor'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('Shirt'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('₹1250.00'), findsOneWidget);
    expect(find.text('PAYMENT SUMMARY'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Advance Paid'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Advance Paid'), findsOneWidget);
    expect(find.text('₹500.00'), findsOneWidget);
    expect(find.text('Total Amount'), findsOneWidget);
    expect(find.text('Measurements (1)'), findsOneWidget);
    expect(find.text('Order Details (1)'), findsNothing);
    expect(find.text('More item details'), findsNothing);
    expect(find.text('OTHER DETAILS'), findsNothing);
    expect(find.text('Tailor Remarks'), findsNothing);
    expect(find.text('Hidden item detail'), findsNothing);
    expect(find.text('Internal Note'), findsNothing);
    expect(find.text('Hidden voucher detail'), findsNothing);

    await tester.tap(find.text('Measurements (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
