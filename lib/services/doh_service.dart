import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum DohProvider {
  nextDns,
  cloudflare,
  google,
  adguard,
  custom,
}

class DnsRecord {
  final String ip;
  final int ttl;
  final DateTime createdAt;

  DnsRecord({
    required this.ip,
    required this.ttl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired {
    final validTtl = ttl > 0 ? ttl : 300;
    return DateTime.now().difference(createdAt).inSeconds > validTtl;
  }
}

class DohTestResult {
  final bool success;
  final int latencyMs;
  final String? resolvedIp;
  final String providerName;
  final String? error;

  const DohTestResult({
    required this.success,
    required this.latencyMs,
    this.resolvedIp,
    required this.providerName,
    this.error,
  });
}

class DohService extends ChangeNotifier {
  static const String _keyEnabled = 'doh_enabled';
  static const String _keyProvider = 'doh_provider';
  static const String _keyNextDnsId = 'doh_nextdns_profile_id';
  static const String _keyCustomEndpoint = 'doh_custom_endpoint';

  bool _isEnabled = true;
  DohProvider _provider = DohProvider.nextDns;
  String _nextDnsProfileId = '';
  String _customEndpoint = '';

  final Map<String, List<DnsRecord>> _cache = {};

  // Bootstrap IPs to avoid circular DNS lookups when resolving DoH servers themselves
  static const Map<String, List<String>> _bootstrapIps = {
    'dns.nextdns.io': ['45.90.28.0', '45.90.30.0'],
    'cloudflare-dns.com': ['1.1.1.1', '1.0.0.1'],
    'dns.google': ['8.8.8.8', '8.8.4.4'],
    'dns.adguard-dns.com': ['94.140.14.14', '94.140.15.15'],
  };

  bool get isEnabled => _isEnabled;
  DohProvider get provider => _provider;
  String get nextDnsProfileId => _nextDnsProfileId;
  String get customEndpoint => _customEndpoint;

  String get currentEndpointUrl {
    switch (_provider) {
      case DohProvider.nextDns:
        final profile = _nextDnsProfileId.trim();
        if (profile.isNotEmpty) {
          return 'https://dns.nextdns.io/$profile';
        }
        return 'https://dns.nextdns.io/dns-query';
      case DohProvider.cloudflare:
        return 'https://cloudflare-dns.com/dns-query';
      case DohProvider.google:
        return 'https://dns.google/resolve';
      case DohProvider.adguard:
        return 'https://dns.adguard-dns.com/dns-query';
      case DohProvider.custom:
        return _customEndpoint.trim().isNotEmpty
            ? _customEndpoint.trim()
            : 'https://dns.nextdns.io/dns-query';
    }
  }

  String get providerDisplayName {
    switch (_provider) {
      case DohProvider.nextDns:
        return _nextDnsProfileId.trim().isNotEmpty
            ? 'NextDNS (${_nextDnsProfileId.trim()})'
            : 'NextDNS (Padrão)';
      case DohProvider.cloudflare:
        return 'Cloudflare (1.1.1.1)';
      case DohProvider.google:
        return 'Google DNS (8.8.8.8)';
      case DohProvider.adguard:
        return 'AdGuard DNS';
      case DohProvider.custom:
        return 'DoH Customizado';
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_keyEnabled) ?? true;
      final providerStr = prefs.getString(_keyProvider);
      if (providerStr != null) {
        _provider = DohProvider.values.firstWhere(
          (p) => p.name == providerStr,
          orElse: () => DohProvider.nextDns,
        );
      }
      _nextDnsProfileId = prefs.getString(_keyNextDnsId) ?? '';
      _customEndpoint = prefs.getString(_keyCustomEndpoint) ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('[DoH] Error loading preferences: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, value);
    } catch (_) {}
  }

  Future<void> setProvider(DohProvider value) async {
    _provider = value;
    clearCache();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProvider, value.name);
    } catch (_) {}
  }

  Future<void> setNextDnsProfileId(String id) async {
    _nextDnsProfileId = id.trim();
    clearCache();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyNextDnsId, _nextDnsProfileId);
    } catch (_) {}
  }

  Future<void> setCustomEndpoint(String url) async {
    _customEndpoint = url.trim();
    clearCache();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCustomEndpoint, _customEndpoint);
    } catch (_) {}
  }

  void clearCache() {
    _cache.clear();
  }

  static bool isIpAddress(String host) {
    return InternetAddress.tryParse(host) != null;
  }

  bool isDohHost(String host) {
    final lower = host.toLowerCase();
    return lower.contains('nextdns.io') ||
        lower.contains('cloudflare-dns.com') ||
        lower.contains('dns.google') ||
        lower.contains('adguard-dns.com') ||
        (_customEndpoint.isNotEmpty && _customEndpoint.contains(lower));
  }

  /// Resolve hostname to IP using DoH
  Future<String?> resolveHost(String host) async {
    if (!_isEnabled) return null;
    if (isIpAddress(host)) return host;

    // Check bootstrap IPs for DoH hosts
    for (final entry in _bootstrapIps.entries) {
      if (host.toLowerCase() == entry.key) {
        return entry.value.first;
      }
    }

    // Check memory cache
    final cached = _cache[host];
    if (cached != null && cached.isNotEmpty) {
      final valid = cached.where((r) => !r.isExpired).toList();
      if (valid.isNotEmpty) {
        return valid.first.ip;
      }
    }

    try {
      final endpoint = currentEndpointUrl;
      final uri = Uri.parse(endpoint).replace(
        queryParameters: {
          'name': host,
          'type': 'A',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/dns-json',
          'User-Agent': 'NekoCast-DoH/1.0',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final answers = data['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          final List<DnsRecord> records = [];
          for (final item in answers) {
            final type = item['type'];
            // Type 1 is DNS A record (IPv4)
            if (type == 1 && item['data'] != null) {
              final ip = item['data'].toString().trim();
              if (isIpAddress(ip)) {
                final ttl = item['TTL'] is int ? item['TTL'] as int : 300;
                records.add(DnsRecord(ip: ip, ttl: ttl));
              }
            }
          }

          if (records.isNotEmpty) {
            _cache[host] = records;
            return records.first.ip;
          }
        }
      }
    } catch (e) {
      debugPrint('[DoH] Resolution failed for $host: $e');
    }

    return null;
  }

  /// Test DoH resolution against a test host
  Future<DohTestResult> testResolution({String testHost = 'animefire.plus'}) async {
    final sw = Stopwatch()..start();
    try {
      final endpoint = currentEndpointUrl;
      final uri = Uri.parse(endpoint).replace(
        queryParameters: {
          'name': testHost,
          'type': 'A',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/dns-json',
          'User-Agent': 'NekoCast-DoH/1.0',
        },
      ).timeout(const Duration(seconds: 5));

      sw.stop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final answers = data['Answer'] as List?;
        String? resolvedIp;
        if (answers != null && answers.isNotEmpty) {
          for (final item in answers) {
            if (item['type'] == 1 && item['data'] != null) {
              resolvedIp = item['data'].toString();
              break;
            }
          }
        }

        if (resolvedIp != null) {
          return DohTestResult(
            success: true,
            latencyMs: sw.elapsedMilliseconds,
            resolvedIp: resolvedIp,
            providerName: providerDisplayName,
          );
        } else {
          return DohTestResult(
            success: false,
            latencyMs: sw.elapsedMilliseconds,
            providerName: providerDisplayName,
            error: 'Nenhum registro A retornado para $testHost.',
          );
        }
      } else {
        return DohTestResult(
          success: false,
          latencyMs: sw.elapsedMilliseconds,
          providerName: providerDisplayName,
          error: 'Código HTTP ${response.statusCode} recebido do servidor DoH.',
        );
      }
    } catch (e) {
      sw.stop();
      return DohTestResult(
        success: false,
        latencyMs: sw.elapsedMilliseconds,
        providerName: providerDisplayName,
        error: e.toString(),
      );
    }
  }
}

/// Global HttpOverrides that routes Dart HttpClient connections through DoH
class DohHttpOverrides extends HttpOverrides {
  final DohService dohService;

  DohHttpOverrides(this.dohService);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      final host = uri.host;
      final port = uri.port;

      if (proxyHost != null) {
        return Socket.startConnect(proxyHost, proxyPort ?? port);
      }

      if (!dohService.isEnabled ||
          DohService.isIpAddress(host) ||
          dohService.isDohHost(host) ||
          host.isEmpty) {
        if (uri.scheme == 'https') {
          return SecureSocket.startConnect(host, port, context: context);
        }
        return Socket.startConnect(host, port);
      }

      try {
        final resolvedIp = await dohService.resolveHost(host);
        if (resolvedIp != null && resolvedIp.isNotEmpty) {
          if (uri.scheme == 'https') {
            final task = await Socket.startConnect(resolvedIp, port);
            final secureSocketFuture = task.socket.then((rawSocket) {
              return SecureSocket.secure(
                rawSocket,
                host: host,
                context: context,
              );
            });
            return ConnectionTask.fromSocket(secureSocketFuture, () => task.cancel());
          } else {
            return await Socket.startConnect(resolvedIp, port);
          }
        }
      } catch (e) {
        debugPrint('[DoH] Connection via resolved IP failed for $host: $e');
      }

      if (uri.scheme == 'https') {
        return SecureSocket.startConnect(host, port, context: context);
      }
      return Socket.startConnect(host, port);
    };

    return client;
  }
}

