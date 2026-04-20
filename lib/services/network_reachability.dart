import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 设备是否具备网络链路（Wi‑Fi / 蜂窝 / 以太网等），**不**对境外 URL 做 HTTP 探测。
///
/// 注意：有链路不代表业务 API 一定可达；实际请求失败时由各服务自行报错。
class NetworkReachability {
  NetworkReachability._();
  static final NetworkReachability instance = NetworkReachability._();

  bool? _cached;
  DateTime? _cachedAt;
  static const Duration _ttl = Duration(seconds: 8);

  /// `true` 表示非 [ConnectivityResult.none]（已连接某种网络）。
  Future<bool> quickCheck() async {
    final now = DateTime.now();
    if (_cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _ttl) {
      return _cached!;
    }

    try {
      final results = await Connectivity().checkConnectivity();
      final online = _hasNetworkLink(results);
      _cached = online;
      _cachedAt = now;
      return online;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NetworkReachability] connectivity check failed: $e');
      }
      _cached = false;
      _cachedAt = now;
      return false;
    }
  }

  static bool _hasNetworkLink(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void invalidate() {
    _cached = null;
    _cachedAt = null;
  }
}
