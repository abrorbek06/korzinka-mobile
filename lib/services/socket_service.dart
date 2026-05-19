import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

typedef SocketMessageHandler = void Function(String type, Map<String, dynamic> payload);

class SocketService {
  io.Socket? _socket;
  final List<SocketMessageHandler> _handlers = [];

  void connect(String token) {
    _socket = io.io(
      '${AppConfig.socketUrl}${AppConfig.socketNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      // Connected to socket
    });

    _socket!.on('message', (data) {
      if (data is Map<String, dynamic>) {
        final type = data['type'] as String? ?? '';
        final payload = data['payload'] as Map<String, dynamic>? ?? {};
        for (final handler in List.of(_handlers)) {
          handler(type, payload);
        }
      }
    });

    _socket!.onDisconnect((_) {
      // Disconnected
    });

    _socket!.onError((error) {
      // Socket error – HTTP remains source of truth
    });
  }

  void addHandler(SocketMessageHandler handler) {
    _handlers.add(handler);
  }

  void removeHandler(SocketMessageHandler handler) {
    _handlers.remove(handler);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _handlers.clear();
  }

  bool get isConnected => _socket?.connected ?? false;
}
