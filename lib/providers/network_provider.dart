import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/peer.dart';
import '../models/message.dart';
import 'chat_provider.dart';

class NetworkProvider extends ChangeNotifier {
  bool _isServerRunning = false;
  HttpServer? _server;
  String? _localIp;
  final List<PeerDevice> _discoveredPeers = [];
  ChatProvider? _chatProvider;
  String _deviceId = 'unknown_device';
  String _deviceName = 'Unknown Device';
  
  List<PeerDevice> get discoveredPeers => _discoveredPeers;
  bool get isServerRunning => _isServerRunning;
  String? get localIp => _localIp;

  void attachChatProvider(ChatProvider provider) {
    _chatProvider = provider;
  }

  void configureLocalIdentity({
    required String deviceId,
    required String deviceName,
  }) {
    _deviceId = deviceId;
    _deviceName = deviceName;
  }
  
  // Получение локального IP адреса
  Future<String?> getLocalIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      _localIp = ip;
      notifyListeners();
      return ip;
    } catch (e) {
      debugPrint('Error getting local IP: $e');
      return null;
    }
  }
  
  // Запуск WebSocket сервера
  Future<void> startServer(int port) async {
    if (_isServerRunning) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isServerRunning = true;
      notifyListeners();
      
      debugPrint('Server started on port $port');
      
      // Обработка входящих подключений
      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((WebSocket socket) {
            _handleConnection(socket);
          });
        }
      });
    } catch (e) {
      debugPrint('Error starting server: $e');
      _isServerRunning = false;
      notifyListeners();
    }
  }
  
  // Обработка WebSocket соединения
  void _handleConnection(WebSocket socket) {
    debugPrint('Client connected');
    
    socket.listen(
      (data) {
        _handleIncomingMessage(data, socket);
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
      },
      onDone: () {
        debugPrint('Client disconnected');
      },
    );
  }
  
  // Обработка входящих сообщений
  void _handleIncomingMessage(dynamic data, WebSocket socket) {
    try {
      final json = jsonDecode(data);
      final type = json['type'];
      
      switch (type) {
        case 'message':
          _handleMessage(json['data'], socket);
          break;
        case 'discovery':
          _handleDiscovery(json['data'], socket);
          break;
        case 'discovery_response':
          _handleDiscoveryResponse(json['data']);
          break;
        case 'sync_request':
          _handleSyncRequest(json['data'], socket);
          break;
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }
  
  // Обработка текстового сообщения
  void _handleMessage(Map<String, dynamic> data, WebSocket socket) {
    final message = ChatMessage.fromJson(data);
    _chatProvider?.addMessage(message);

    // Подтверждаем доставку отправителю.
    socket.add(jsonEncode({
      'type': 'message_ack',
      'data': {
        'messageId': message.id,
      }
    }));
  }
  
  // Обработка обнаружения устройства
  void _handleDiscovery(Map<String, dynamic> data, WebSocket socket) {
    final peer = PeerDevice.fromJson(data);
    _addOrUpdatePeer(peer);

    socket.add(jsonEncode({
      'type': 'discovery_response',
      'data': _localPeerData(),
    }));
  }

  void _handleDiscoveryResponse(Map<String, dynamic> data) {
    final peer = PeerDevice.fromJson(data);
    _addOrUpdatePeer(peer);
  }
  
  // Обработка запроса синхронизации
  void _handleSyncRequest(Map<String, dynamic> data, WebSocket socket) {
    final messages = _chatProvider?.messages ?? const <ChatMessage>[];
    
    socket.add(jsonEncode({
      'type': 'sync_response',
      'data': messages.map((m) => m.toJson()).toList(),
    }));
  }
  
  // Подключение к пиру
  Future<WebSocket?> connectToPeer(String ipAddress, int port) async {
    try {
      final socket = await WebSocket.connect(
        'ws://$ipAddress:$port',
      ).timeout(
        const Duration(milliseconds: 900),
      );
      return socket;
    } catch (e) {
      return null;
    }
  }
  
  // Отправка сообщения пиру
  Future<MessageStatus> sendMessageToPeer(PeerDevice peer, ChatMessage message) async {
    try {
      var targetIp = peer.ipAddress;
      var targetPort = peer.port;

      // Если чат открыт из истории и IP еще не известен, пытаемся резолвить пира автоматически.
      if (targetIp.isEmpty) {
        final knownPeer = _discoveredPeers
            .cast<PeerDevice?>()
            .firstWhere((p) => p?.id == peer.id, orElse: () => null);
        if (knownPeer != null) {
          targetIp = knownPeer.ipAddress;
          targetPort = knownPeer.port;
        } else {
          await discoverPeers();
          final refreshedPeer = _discoveredPeers
              .cast<PeerDevice?>()
              .firstWhere((p) => p?.id == peer.id, orElse: () => null);
          if (refreshedPeer != null) {
            targetIp = refreshedPeer.ipAddress;
            targetPort = refreshedPeer.port;
          }
        }
      }

      if (targetIp.isEmpty) return MessageStatus.failed;

      final socket = await connectToPeer(targetIp, targetPort);
      if (socket != null) {
        socket.add(jsonEncode({
          'type': 'message',
          'data': message.toJson(),
        }));

        try {
          final dynamic response = await socket.first.timeout(
            const Duration(milliseconds: 1500),
          );
          final payload = jsonDecode(response as String) as Map<String, dynamic>;
          if (payload['type'] == 'message_ack') {
            final data = Map<String, dynamic>.from(payload['data'] as Map);
            if (data['messageId'] == message.id) {
              await socket.close();
              return MessageStatus.delivered;
            }
          }
        } catch (_) {
          // Если ack не пришел, но сокет открылся и отправка прошла - считаем как sent.
          await socket.close();
          return MessageStatus.sent;
        }

        await socket.close();
        return MessageStatus.sent;
      }
      return MessageStatus.failed;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return MessageStatus.failed;
    }
  }
  
  // Поиск устройств в сети (упрощённый для теста)
  Future<void> discoverPeers() async {
    _discoveredPeers.clear();
    notifyListeners();
    
    final ip = await getLocalIp();
    if (ip == null) return;
    
    final subnet = ip.substring(0, ip.lastIndexOf('.'));
    final selfLastOctet = int.tryParse(ip.split('.').last);

    final probes = <Future<void>>[];
    for (var i = 1; i <= 254; i++) {
      if (i == selfLastOctet) continue;
      final targetIp = '$subnet.$i';

      probes.add(_probePeer(targetIp, 8080));
      if (probes.length >= 24) {
        await Future.wait(probes);
        probes.clear();
      }
    }

    if (probes.isNotEmpty) {
      await Future.wait(probes);
    }
    notifyListeners();
  }

  Future<void> _probePeer(String ipAddress, int port) async {
    final socket = await connectToPeer(ipAddress, port);
    if (socket == null) return;

    try {
      socket.add(jsonEncode({
        'type': 'discovery',
        'data': _localPeerData(),
      }));

      final dynamic response = await socket.first.timeout(
        const Duration(milliseconds: 700),
      );

      final payload = jsonDecode(response as String) as Map<String, dynamic>;
      if (payload['type'] != 'discovery_response') return;

      final data = Map<String, dynamic>.from(payload['data'] as Map);
      data['ipAddress'] = ipAddress;
      _addOrUpdatePeer(PeerDevice.fromJson(data));
    } catch (_) {
      // Ignore timeout/parse errors while probing subnet.
    } finally {
      await socket.close();
    }
  }

  Map<String, dynamic> _localPeerData() {
    return {
      'id': _deviceId,
      'name': _deviceName,
      'ipAddress': _localIp ?? '',
      'port': 8080,
      'lastSeen': DateTime.now().toIso8601String(),
      'isOnline': true,
    };
  }

  void _addOrUpdatePeer(PeerDevice peer) {
    final index = _discoveredPeers.indexWhere((p) => p.id == peer.id);
    if (index == -1) {
      _discoveredPeers.add(peer);
    } else {
      _discoveredPeers[index] = peer;
    }
    notifyListeners();
  }
  
  // Остановка сервера
  void stopServer() {
    _server?.close();
    _isServerRunning = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    stopServer();
    super.dispose();
  }

  // Добавление ручного пира
  void addManualPeer(PeerDevice peer) {
    final exists = _discoveredPeers.any((p) => p.id == peer.id);
    if (!exists) {
      _discoveredPeers.add(peer);
      notifyListeners();
    }
  }
}