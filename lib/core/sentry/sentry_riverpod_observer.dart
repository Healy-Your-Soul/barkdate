import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

base class SentryProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('riverpod.provider', context.provider.name ?? context.provider.runtimeType.toString());
      },
    );
    super.providerDidFail(context, error, stackTrace);
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (newValue is AsyncError) {
      Sentry.captureException(
        newValue.error,
        stackTrace: newValue.stackTrace,
        withScope: (scope) {
          scope.setTag('riverpod.provider', context.provider.name ?? context.provider.runtimeType.toString());
        },
      );
    }
    super.didUpdateProvider(context, previousValue, newValue);
  }
}
