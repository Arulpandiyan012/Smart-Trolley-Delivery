import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:smart_trolley_delivery/models/order_model.dart';
import 'package:smart_trolley_delivery/screens/dashboard/bloc/dashboard_repository.dart';
import 'package:smart_trolley_delivery/services/location_tracking_service.dart';

// --- Events ---
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object> get props => [];
}

class FetchOrdersEvent extends DashboardEvent {}

class UpdateOrderStatusEvent extends DashboardEvent {
  final int orderId;
  final String newStatus;
  const UpdateOrderStatusEvent(this.orderId, this.newStatus);

  @override
  List<Object> get props => [orderId, newStatus];
}

// --- States ---
abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<OrderModel> activeOrders;
  final List<OrderModel> historyOrders;

  const DashboardLoaded({
    required this.activeOrders,
    required this.historyOrders,
  });

  @override
  List<Object> get props => [activeOrders, historyOrders];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLoC ---
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardRepository repository;

  DashboardBloc({required this.repository}) : super(DashboardInitial()) {
    on<FetchOrdersEvent>((event, emit) async {
      emit(DashboardLoading());
      try {
        final response = await repository.getOrders();
        emit(
          DashboardLoaded(
            activeOrders: response.activeOrders,
            historyOrders: response.historyOrders,
          ),
        );
      } catch (e) {
        emit(DashboardError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<UpdateOrderStatusEvent>((event, emit) async {
      // Ideally we'd emit a loading state or just refresh after success
      try {
        final success = await repository.updateOrderStatus(
          event.orderId,
          event.newStatus,
        );
        if (success) {
          if (event.newStatus == 'picked_up') {
            LocationTrackingService().startTracking(event.orderId.toString());
          } else if (event.newStatus == 'delivered' || event.newStatus == 'completed') {
            LocationTrackingService().stopTracking();
          }
          add(FetchOrdersEvent()); // Refresh lists
        }
      } catch (e) {
        emit(DashboardError('Update failed: $e'));
      }
    });
  }
}
