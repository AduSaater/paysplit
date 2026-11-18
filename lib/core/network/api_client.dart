import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage_service.dart';
import 'api_endpoints.dart';

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.isNetworkError = false,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final bool isNetworkError;

  @override
  String toString() => message;
}

/// Normalizes either a direct JSON list or a paginated `{items/data: [...]}` envelope.
List<Map<String, dynamic>> extractList(dynamic raw) {
  if (raw is List) {
    return raw.cast<Map<String, dynamic>>();
  }
  if (raw is Map<String, dynamic>) {
    final list = raw['items'] ?? raw['data'];
    if (list is List) {
      return list.cast<Map<String, dynamic>>();
    }
  }
  return [];
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage);
});

class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor(_storage));
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  late final Dio _dio;
  final SecureStorageService _storage;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(path, data: data, options: options);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(path, data: data, options: options);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(path, data: data, options: options);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.error is SocketException) {
      return ApiException(
        message: 'Connection issue. Please check your internet and try again.',
        isNetworkError: true,
      );
    }

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String message = 'Something went wrong. Please try again.';
    String? code;

    if (data is Map<String, dynamic>) {
      code = data['code']?.toString();
      final rawMsg = data['message'];
      if (rawMsg is String) {
        message = rawMsg;
      } else if (rawMsg is List && rawMsg.isNotEmpty) {
        message = rawMsg.first.toString();
      }
    } else if (statusCode == 401) {
      message = 'Your session has expired. Please sign in again.';
    } else if (statusCode != null && statusCode >= 500) {
      message = 'Server is temporarily unavailable. Please try again shortly.';
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      code: code,
    );
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);
  final SecureStorageService _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Allow callers to explicitly pass Authorization (e.g. setupToken)
    if (!options.headers.containsKey('Authorization')) {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

/// Retries idempotent GET requests on transient network/5xx errors with backoff.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);
  final Dio _dio;
  static const int _maxRetries = 2;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isGet = err.requestOptions.method.toUpperCase() == 'GET';
    final retries = (err.requestOptions.extra['retries'] as int?) ?? 0;

    final shouldRetry = isGet &&
        retries < _maxRetries &&
        (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.connectionError ||
            (err.response?.statusCode != null &&
                err.response!.statusCode! >= 500));

    if (!shouldRetry) {
      return handler.next(err);
    }

    final nextRetry = retries + 1;
    await Future<void>.delayed(Duration(milliseconds: 500 * nextRetry));

    err.requestOptions.extra['retries'] = nextRetry;
    try {
      final response = await _dio.fetch<dynamic>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
