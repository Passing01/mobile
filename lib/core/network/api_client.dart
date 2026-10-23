import 'package:dio/dio.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/network/api_exceptions.dart';
import 'package:qvgestion_mobile/core/network/auth_interceptor.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/storage/token_storage.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Client HTTP principal de l'application QvGestion
class ApiClient {
  late final Dio _dio;
  final TokenStorage tokenStorage;
  final void Function()? onTokenExpired;

  ApiClient({
    required this.tokenStorage,
    Dio? dio,
    this.onTokenExpired,
  }) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: EnvConfig.apiBaseUrl,
            connectTimeout: EnvConfig.connectTimeout,
            receiveTimeout: EnvConfig.receiveTimeout,
            sendTimeout: EnvConfig.sendTimeout,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );

    _dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: tokenStorage,
        dio: _dio,
        onTokenExpired: onTokenExpired,
      ),
    );

    // Logging interceptor sécurisé
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          AppLogger.d('➡️ [${options.method}] ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.d('⬅️ [${response.statusCode}] ${response.requestOptions.uri}');
          return handler.next(response);
        },
        onError: (error, handler) {
          final uri = error.requestOptions.uri;
          final method = error.requestOptions.method;
          final status = error.response?.statusCode != null
              ? 'HTTP ${error.response!.statusCode}'
              : 'ERR_RESEAU';
          final msg = error.message ?? error.toString();
          AppLogger.error('❌ [$status] $method ${uri.path}: $msg', tag: 'ApiClient');
          DebugInfo.instance.setLastApiError('$method ${uri.path} -> $status ($msg)');
          return handler.next(error);
        },
      ),
    );
  }

  /// Instance interne Dio exposée pour les cas spécifiques (téléchargement de gros fichiers PMTiles, etc.)
  Dio get dio => _dio;

  /// Effectue une requête HTTP GET
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Effectue une requête HTTP POST
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Effectue une requête HTTP PUT
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Effectue une requête HTTP PATCH
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Effectue une requête HTTP DELETE
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
