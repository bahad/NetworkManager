// ignore_for_file: depend_on_referenced_packages, prefer_typing_uninitialized_variables, unused_local_variable

import 'dart:io';
import 'dart:isolate';
import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:get/get_connect/http/src/status/http_status.dart';
import 'package:karaca/app/controllers/user_view_model.dart';
import 'package:karaca/app/ui/global_widgets/kloading.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../../base/model/base_model.dart';
import '../../constants/app_constants.dart';
import '../../constants/enums/preferences_keys.dart';
import '../cache/cache_manager.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

class NetworkManager {
  static NetworkManager? _instance;
  static NetworkManager get instance {
    _instance ??= NetworkManager._init();
    return _instance!;
  }

  UserViewModel? userViewModel;

  String? uid;

  NetworkManager._init() {
    initManager();
  }
  String? userAgent;

  initManager() async {
    final BaseOptions baseOptions = BaseOptions(
      baseUrl: ApplicationConstants.instance.baseURL,
      headers: headers(),
      validateStatus: (_) => true,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
    _dio = Dio(baseOptions);

    if (ApplicationConstants.instance.proxyIsEnabled) {
      debugPrint("Proxy is enabled: ${ApplicationConstants.instance.proxyIsEnabled}");
      const proxyString = 'localhost:9090';

      // ignore: deprecated_member_use
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (url) {
          debugPrint('Proxy: $proxyString');
          return 'PROXY $proxyString';
        };

        client.badCertificateCallback = (X509Certificate cert, String host, int port) => Platform.isAndroid;
        return;
      };
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String? platform = Platform.isAndroid ? "Android" : "IOS";
      String? androidInfo = Platform.isAndroid ? (await deviceInfo.androidInfo).version.release : "";
      String? iosInfo = Platform.isIOS ? (await deviceInfo.iosInfo).systemVersion : "";
      String? deviceSoftwareVersion = Platform.isAndroid ? androidInfo : iosInfo;
      String? userAgent = "$platform ${packageInfo.version}+${packageInfo.buildNumber} ($deviceSoftwareVersion)";
    }

    if (kDebugMode) {
      final talker = Talker();

      _dio.interceptors.add(
        TalkerDioLogger(
          settings: const TalkerDioLoggerSettings(
            printRequestData: false,
            printResponseData: false,
            printResponseMessage: true,
            printResponseHeaders: false,
            printRequestHeaders: false,
          ),
          talker: talker,
        ),
      );
    }
    if (ApplicationConstants.instance.chuckerIsEnabled) {
      _dio.interceptors.add(ChuckerDioInterceptor());
    }
  }

  Map<String, String>? headers() {
    String? token = CacheManager.instance.getValue(PreferencesKeys.token);
    if (token == null) {
      return {
        "Charset": "utf-8",
        "X-STORE-ID": ApplicationConstants.instance.xStoreId,
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Agent-Id": "$uid",
        "X-API-Key": "mobil",
        "User-Agent": userAgent ?? "",
        "X-CUSTOMER-ID": "${userViewModel?.profileInfoModel?.data?.customerId ?? ""}",
      };
    } else {
      return {
        "Charset": "utf-8",
        "Bearer": token,
        "X-STORE-ID": ApplicationConstants.instance.xStoreId,
        "Accept": "application/json",
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "X-Agent-Id": "$uid",
        "X-API-Key": "mobil",
        "User-Agent": userAgent ?? "",
        "X-CUSTOMER-ID": "${userViewModel?.profileInfoModel?.data?.customerId ?? ""}",
      };
    }
  }

  late Dio _dio;

  Dio get dio => _dio;

  Future get<T extends IBaseModel>({
    required String path,
    T? model,
    Map<String, dynamic>? queryParameters,
    BuildContext? context,
  }) async {
    ReceivePort receivePort = ReceivePort();
    var responseData;
    try {
      if (context != null) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!Loader.isShown) {
          Loader.show(context, progressIndicator: const KLoading(), isAppbarOverlay: false);
        }
      }
      Response<dynamic>? response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(
          headers: headers(),
        ),
      );
      if (response.statusCode == HttpStatus.internalServerError) {
      } else {
        if (model == null) {
          var value = response.data;
          if (value is Map) {
            value["statusCode"] = response.statusCode;
          }
          responseData = value;
        } else {
          await compute(
            jsonBodyParserWithCompute,
            [model, response.data, receivePort.sendPort],
          );
          responseData = receivePort.first;
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (context != null) {
        if (Loader.isShown) {
          Loader.hide();
        }
      }
      receivePort.close();
    }
    return responseData;
  }

  Future delete<T extends IBaseModel>({
    required String path,
    T? model,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? data,
    BuildContext? context,
  }) async {
    ReceivePort receivePort = ReceivePort();
    var responseData;
    try {
      if (context != null) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!Loader.isShown) {
          Loader.show(context, progressIndicator: const KLoading(), isAppbarOverlay: false);
        }
      }
      Response<dynamic>? response = await _dio.delete(
        path,
        queryParameters: queryParameters,
        data: data,
        options: Options(
          headers: headers(),
        ),
      );

      if (response.statusCode == HttpStatus.internalServerError) {
      } else {
        if (model == null) {
          var value = response.data;
          if (value is Map) {
            value["statusCode"] = response.statusCode;
          }
          responseData = value;
        } else {
          await compute(
            jsonBodyParserWithCompute,
            [model, response.data, receivePort.sendPort],
          );
          responseData = receivePort.first;
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (context != null) {
        if (Loader.isShown) {
          Loader.hide();
        }
      }
      receivePort.close();
    }
    return responseData;
  }

  Future put<T extends IBaseModel>({
    required String path,
    T? model,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? data,
    BuildContext? context,
    Options? options,
  }) async {
    ReceivePort receivePort = ReceivePort();
    var responseData;
    try {
      if (context != null) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!Loader.isShown) {
          Loader.show(context, progressIndicator: const KLoading(), isAppbarOverlay: false);
        }
      }
      Response<dynamic>? response = await _dio.put(
        path,
        queryParameters: queryParameters,
        data: data,
        options: Options(
          headers: headers(),
        ),
      );

      if (response.statusCode == HttpStatus.internalServerError) {
      } else {
        if (model == null) {
          var value = response.data;
          if (value is Map) {
            value["statusCode"] = response.statusCode;
          }
          responseData = value;
        } else {
          await compute(
            jsonBodyParserWithCompute,
            [model, response.data, receivePort.sendPort],
          );
          responseData = receivePort.first;
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (context != null) {
        if (Loader.isShown) {
          Loader.hide();
        }
      }
      receivePort.close();
    }
    return responseData;
  }

  Future post<T extends IBaseModel>({
    required String path,
    T? model,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? data,
    BuildContext? context,
    Options? options,
  }) async {
    ReceivePort receivePort = ReceivePort();
    var responseData;
    try {
      if (context != null) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!Loader.isShown) {
          Loader.show(context, progressIndicator: const KLoading(), isAppbarOverlay: false);
        }
      }
      Response<dynamic>? response = await _dio.post(
        path,
        queryParameters: queryParameters,
        data: data,
        options: Options(
          headers: headers(),
        ),
      );
      if (response.statusCode == HttpStatus.internalServerError) {
      } else {
        if (model == null) {
          var value = response.data;
          if (value is Map) {
            value["statusCode"] = response.statusCode;
          }
          responseData = value;
        } else {
          await compute(
            jsonBodyParserWithCompute,
            [model, response.data, receivePort.sendPort],
          );
          responseData = receivePort.first;
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (context != null) {
        if (Loader.isShown) {
          Loader.hide();
        }
      }
      receivePort.close();
    }
    return responseData;
  }

  Future patch<T extends IBaseModel>({
    required String path,
    T? model,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? data,
    BuildContext? context,
    Options? options,
  }) async {
    ReceivePort receivePort = ReceivePort();
    var responseData;
    try {
      if (context != null) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!Loader.isShown) {
          Loader.show(context, progressIndicator: const KLoading(), isAppbarOverlay: false);
        }
      }
      Response<dynamic>? response = await _dio.patch(
        path,
        queryParameters: queryParameters,
        data: data,
        options: Options(
          headers: headers(),
        ),
      );

      if (response.statusCode == HttpStatus.internalServerError) {
      } else {
        if (model == null) {
          var value = response.data;
          if (value is Map) {
            value["statusCode"] = response.statusCode;
          }
          responseData = value;
        } else {
          await compute(
            jsonBodyParserWithCompute,
            [model, response.data, receivePort.sendPort],
          );
          responseData = receivePort.first;
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (context != null) {
        if (Loader.isShown) {
          Loader.hide();
        }
      }
      receivePort.close();
    }
    return responseData;
  }
}

jsonBodyParserWithCompute<T>(args) async {
  IBaseModel model = args[0];
  dynamic data = args[1];
  SendPort port = args[2];
  try {
    if (data is List) {
      port.send(data.map((e) => model.fromJson(e)).toList().cast<T>());
    } else if (data is Map) {
      port.send(model.fromJson(data));
    } else {
      port.send(data);
    }
  } catch (ex) {
    port.send(data);
  }
}
