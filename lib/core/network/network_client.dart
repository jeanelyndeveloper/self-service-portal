import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class NetworkClient {
  late final Dio _dio;

  NetworkClient({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? AppConstants.baseUrl,
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
        'X-Requested-With': 'XMLHttpRequest',
      },
    ));
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) =>
      _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      );

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) =>
      _dio.post<T>(
        path,
        data: data,
        options: headers == null ? null : Options(headers: headers),
      );
}
