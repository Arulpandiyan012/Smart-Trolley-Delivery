import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_trolley_delivery/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:smart_trolley_delivery/screens/dashboard/bloc/dashboard_repository.dart';
import 'package:smart_trolley_delivery/models/order_model.dart';
import 'package:smart_trolley_delivery/screens/profile/view/profile_screen.dart';
import 'package:smart_trolley_delivery/screens/order_details/view/order_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardBloc(repository: DashboardRepository())..add(FetchOrdersEvent()),
      child: DefaultTabController(
        length: 2,
        child: WillPopScope(
          onWillPop: () async {
            if (_currentIndex != 0) {
              setState(() {
                _currentIndex = 0;
              });
              return false;
            }
            return true;
          },
          child: Scaffold(
            appBar: _currentIndex == 0 ? AppBar(
            title: const Text('My Deliveries'),
            bottom: const TabBar(
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Active Orders'),
                Tab(text: 'History'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<DashboardBloc>().add(FetchOrdersEvent());
                },
              ),
            ],
          ) : null,
          body: _currentIndex == 0 ? BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              if (state is DashboardLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is DashboardError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${state.message}'),
                      ElevatedButton(
                        onPressed: () => context.read<DashboardBloc>().add(FetchOrdersEvent()),
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                );
              } else if (state is DashboardLoaded) {
                return TabBarView(
                  children: [
                    _buildOrderList(context, state.activeOrders, true),
                    _buildOrderList(context, state.historyOrders, false),
                  ],
                );
              }
              return const Center(child: Text('Initializing...'));
            },
          ) : const ProfileScreen(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ), // Scaffold
        ), // WillPopScope
      ), // DefaultTabController
    ); // return
  }

  Widget _buildOrderList(BuildContext context, List<OrderModel> orders, bool isActive) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.inbox : Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(isActive ? 'No active deliveries.' : 'No past deliveries yet.', 
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(FetchOrdersEvent());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.orderNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status,
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildIconText(Icons.person, order.customerName),
                  const SizedBox(height: 8),
                  _buildIconText(Icons.shopping_bag, order.items),
                  const SizedBox(height: 8),
                  _buildIconText(Icons.access_time, order.date),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildIconText(Icons.payments, 'Total: ${order.total}'),
                      ),
                      if (isActive)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<DashboardBloc>(),
                                  child: OrderDetailsScreen(order: order),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_ios, size: 14),
                          label: const Text('Details'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
          ),
        ),
      ],
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
      case 'closed':
        return Colors.green;
      case 'canceled':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
