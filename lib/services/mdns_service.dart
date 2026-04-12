import 'dart:async';
import 'dart:developer';

import 'package:multicast_dns/multicast_dns.dart';

class MdnsDiscoveredPairingService {
  const MdnsDiscoveredPairingService({
    required this.name,
    required this.host,
    required this.port,
  });

  final String name;
  final String host;
  final int port;

  String get address => '$host:$port';
}

class MdnsService {
  static const _pairingServiceType = '_adb-tls-pairing._tcp.local';
  static const _scanTimeout = Duration(seconds: 4);

  /// Discovers Android devices currently in wireless debugging pairing mode.
  ///
  /// Returns within 4 seconds even if no services are found.
  Future<List<MdnsDiscoveredPairingService>> discoverPairingServices() {
    return _doDiscover().timeout(_scanTimeout, onTimeout: () => []);
  }

  Future<List<MdnsDiscoveredPairingService>> _doDiscover() async {
    final client = MDnsClient();
    final services = <MdnsDiscoveredPairingService>[];

    try {
      await client.start();

      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_pairingServiceType),
      )) {
        await for (final SrvResourceRecord srv
            in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final IPAddressResourceRecord ip
              in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            services.add(
              MdnsDiscoveredPairingService(
                name: ptr.domainName,
                host: ip.address.address,
                port: srv.port,
              ),
            );
          }
        }
      }
    } catch (e, st) {
      log('MdnsService.discoverPairingServices error: $e\n$st');
    } finally {
      client.stop();
    }

    return services;
  }
}
