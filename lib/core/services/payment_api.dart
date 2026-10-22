import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Connection details and helpers for the Vercel payment API (`api/`).
abstract final class PaymentApi {
  /// Set with `--dart-define=PAYMENT_API_BASE_URL=...`. Required for
  /// Android/iOS builds that talk to a non-default deployment.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'PAYMENT_API_BASE_URL',
  );

  static const String _defaultBaseUrl = 'https://www.madebyhands.shop';

  /// The web build is served by the same Vercel project as the API, so it
  /// talks to its own origin unless a base URL is configured explicitly.
  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    return kIsWeb ? Uri.base.origin : _defaultBaseUrl;
  }

  static Dio createClient() => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
    ),
  );

  /// A fresh Firebase ID token for the signed-in user.
  static Future<String> idToken({bool forceRefresh = false}) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(
      forceRefresh,
    );
    if (token == null || token.isEmpty) {
      throw StateError('Please sign in again before continuing.');
    }
    return token;
  }

  /// The server's `error` text when it sent one, else [fallback].
  static String errorMessage(DioException error, {required String fallback}) {
    final body = error.response?.data;
    final serverMessage = body is Map ? body['error']?.toString().trim() : null;
    if (serverMessage != null && serverMessage.isNotEmpty) return serverMessage;
    if (error.response == null) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return fallback;
  }

  static bool isNetworkFailure(DioException error) =>
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError;
}

/// Outcome of [OrderActionsApi.rejectOrder].
class RejectOrderResult {
  final bool refunded;
  final String? warning;

  const RejectOrderResult({required this.refunded, this.warning});
}

/// Order actions that move money and therefore run on the server.
class OrderActionsApi {
  final Dio _dio;

  OrderActionsApi({Dio? dio}) : _dio = dio ?? PaymentApi.createClient();

  /// Rejects an order before dispatch. Paid orders are refunded by the API.
  Future<RejectOrderResult> rejectOrder({
    required String orderId,
    required String reason,
  }) async {
    final token = await PaymentApi.idToken();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/reject-order',
        data: {'orderId': orderId, 'reason': reason},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return RejectOrderResult(refunded: response.data?['refunded'] == true);
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map && body['rejected'] == true) {
        // The order was rejected; only the refund needs an admin retry.
        return RejectOrderResult(
          refunded: false,
          warning: PaymentApi.errorMessage(error, fallback: 'Refund pending.'),
        );
      }
      throw StateError(
        PaymentApi.errorMessage(
          error,
          fallback: 'Could not reject the order. Please try again.',
        ),
      );
    }
  }
}

/// Suspending or reinstating a user must disable/enable their actual Firebase
/// Auth account (and revoke any open session), which only the Admin SDK can
/// do — so this runs on the server, never as a direct Firestore write.
class UserModerationApi {
  final Dio _dio;

  UserModerationApi({Dio? dio}) : _dio = dio ?? PaymentApi.createClient();

  Future<void> setModeration({
    required String uid,
    required int level,
    required String reason,
    bool immediate = false,
  }) async {
    final token = await PaymentApi.idToken();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/suspend-user',
        data: {
          'uid': uid,
          'level': level,
          'reason': reason,
          'immediate': immediate,
          // Backward compatibility while the staged endpoint is rolling out.
          'suspend': level == 3,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final responseLevel = response.data?['level'];
      final legacyAuthOnlyResponse =
          responseLevel == null && (level == 0 || level == 3);
      if (!legacyAuthOnlyResponse && responseLevel != level) {
        throw StateError(
          'The server has not been updated for staged creator warnings yet.',
        );
      }
    } on DioException catch (error) {
      throw StateError(
        PaymentApi.errorMessage(
          error,
          fallback: 'Could not update this user. Please try again.',
        ),
      );
    }
  }
}
