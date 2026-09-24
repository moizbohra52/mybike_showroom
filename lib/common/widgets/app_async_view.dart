import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/common/widgets/app_error_state.dart';
import 'package:mybike_showroom/common/widgets/app_loading.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';

/// Loading / error / data states of an [AsyncValue] with the MyBike widgets.
/// Errors show the mapped, user-safe message (and trace code when unknown).
class AppAsyncView<T> extends StatelessWidget {
  const AppAsyncView({required this.value, required this.data, this.onRetry, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncValue<T>(:final T value, hasValue: true) => data(value),
      AsyncValue<T>(:final Object error, :final StackTrace stackTrace) => Center(
          child: AppErrorState(
            title: 'Could not load',
            message: AppFeedback.describe(ErrorMapper.map(error, stackTrace)),
            onRetry: onRetry,
          ),
        ),
      _ => const Center(child: AppLoading()),
    };
  }
}

/// SnackBar feedback for user actions.
abstract final class AppFeedback {
  /// Runs [action]; shows [success] or the failure message. Returns true on success.
  static Future<bool> run(BuildContext context, Future<void> Function() action, {String? success}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
      return true;
    } catch (error, stackTrace) {
      messenger.showSnackBar(SnackBar(content: Text(describe(ErrorMapper.map(error, stackTrace)))));
      return false;
    }
  }

  static String describe(AppFailure failure) =>
      failure.traceCode == null ? failure.message : '${failure.message} (ref ${failure.traceCode})';
}
