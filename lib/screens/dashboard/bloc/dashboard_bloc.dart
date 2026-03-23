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

class FetchAvailableOrdersEvent extends DashboardEvent {}

class AcceptOrderEvent extends DashboardEvent {
  final int orderId;
  const AcceptOrderEvent(this.orderId);

  @override
  List<Object> get props => [orderId];
}

class UpdateOrderStatusEvent extends DashboardEvent {
  final int orderId;
  final String newStatus;
  const UpdateOrderStatusEvent(this.orderId, this.newStatus);

  @override
  List<Object> get props => [orderId, newStatus];
}

class StartTripEvent extends DashboardEvent {
  final int orderId;
  const StartTripEvent(this.orderId);

  @override
  List<Object> get props => [orderId];
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
  final List<OrderModel> availableOrders;

  const DashboardLoaded({
    required this.activeOrders,
    required this.historyOrders,
    this.availableOrders = const [],
  });

  @override
  List<Object> get props => [activeOrders, historyOrders, availableOrders];
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
        final available = await repository.getAvailableOrders();
        emit(
          DashboardLoaded(
            activeOrders: response.activeOrders,
            historyOrders: response.historyOrders,
            availableOrders: available,
          ),
        );
      } catch (e) {
        emit(DashboardError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<AcceptOrderEvent>((event, emit) async {
      try {
        final success = await repository.acceptOrder(event.orderId);
        if (success) {
          add(FetchOrdersEvent()); // Refresh lists
        }
      } catch (e) {
        emit(DashboardError('Failed to accept order: $e'));
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
    on<StartTripEvent>((event, emit) async {
       try {
         // Optionally update a "trip_started" flag on backend if needed
         // For now, we just initialize the tracking service's startTrip
         await LocationTrackingService().startTrip(event.orderId.toString());
         add(FetchOrdersEvent()); // Refresh lists to show "Trip Started" UI if any
       } catch (e) {
         emit(DashboardError('Failed to start trip: $e'));
       }
    });
  }
}
