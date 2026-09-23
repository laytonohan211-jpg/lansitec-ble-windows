import 'package:dio/dio.dart';
import 'package:flutter_blue/utils/interceptor/http_interceptor.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

typedef OnErrorCallback = void Function(dynamic error);
typedef OnLoadCallback = void Function(bool isLoading);

class DioClient {
  final Dio _dio;
  final OnErrorCallback? onError;
  final OnLoadCallback? onLoad;

  DioClient._internal(this._dio, {this.onError, this.onLoad});

  factory DioClient({
    required String baseUrl,
    Map<String, String>? headers,
    Duration? timeout,
    bool debug = false,
    OnErrorCallback? onError,
    OnLoadCallback? onLoad,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout ?? const Duration(seconds: 10),
        receiveTimeout: timeout ?? const Duration(seconds: 10),
        headers: headers,
      ),
    );

    if (debug) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
        ),
      );
    }

    dio.interceptors.add(
      HttpInterceptor(onErrorCallback: onError, onLoadCallback: onLoad),
    );

    return DioClient._internal(dio, onError: onError, onLoad: onLoad);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } catch (e) {
      rethrow;
    }
  }
}
