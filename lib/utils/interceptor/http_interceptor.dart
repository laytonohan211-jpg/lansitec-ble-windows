import 'package:dio/dio.dart';

class HttpInterceptor extends QueuedInterceptor {
  final void Function(dynamic error)? onErrorCallback;
  final void Function(bool isLoading)? onLoadCallback;

  HttpInterceptor({this.onErrorCallback, this.onLoadCallback});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    onLoadCallback?.call(true);
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    onLoadCallback?.call(false);
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    onLoadCallback?.call(false);
    onErrorCallback?.call(err);
    super.onError(err, handler);
  }
}
