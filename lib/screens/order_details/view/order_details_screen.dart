import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_trolley_delivery/models/order_model.dart';
import 'package:smart_trolley_delivery/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsScreen({Key? key, required this.order}) : super(key: key);

  Future<void> _launchMaps(String destination) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=\$destination',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint('Could not launch directions');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:\$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint('Could not launch phone dialer');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCompleted = [
      'delivered',
      'completed',
      'canceled',
    ].contains(order.status.toLowerCase());

    return Scaffold(
      appBar: AppBar(title: Text('Order \${order.orderNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _getStatusColor(order.status).withOpacity(0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Status:',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      order.status,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Customer Details Card
            const Text(
              'Customer Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            order.customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.blue),
                          // Placeholder phone number - in real app, get from order specifics
                          onPressed: () => _makePhoneCall('9876543210'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '123 Delivery Street, Example City, EX 12345',
                            style: TextStyle(fontSize: 14),
                          ), // Placeholder address
                        ),
                        IconButton(
                          icon: const Icon(Icons.map, color: Colors.blue),
                          onPressed: () =>
                              _launchMaps('123 Delivery Street, Example City'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Order Items Summary
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.items, style: const TextStyle(fontSize: 14)),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total to Collect',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\${order.total}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isCompleted
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (order.status.toLowerCase() == 'assigned' ||
                        order.status.toLowerCase() == 'processing')
                      ElevatedButton(
                        onPressed: () {
                          context.read<DashboardBloc>().add(
                            UpdateOrderStatusEvent(order.id, 'picked_up'),
                          );
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Mark as Picked Up',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    if (order.status.toLowerCase() == 'picked_up' ||
                        order.status.toLowerCase() == 'picked up')
                      ElevatedButton(
                        onPressed: () {
                          context.read<DashboardBloc>().add(
                            UpdateOrderStatusEvent(order.id, 'delivered'),
                          );
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Mark as Delivered',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'picked_up':
      case 'picked up':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
