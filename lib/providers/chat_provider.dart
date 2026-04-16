import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/peer.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  List<PeerDevice> _peers = [];
  
  List<ChatMessage> get messages => _messages;
  List<PeerDevice> get peers => _peers;
  
  // Загрузка сообщений из локального хранилища
  Future<void> loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getStringList('messages') ?? [];
      
      _messages = messagesJson
          .map((json) => ChatMessage.fromJson(jsonDecode(json)))
          .toList();
      
      // Сортируем по времени
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }
  
  // Добавление нового сообщения
  Future<void> addMessage(ChatMessage message) async {
    try {
      final exists = _messages.any((m) => m.id == message.id);
      if (exists) return;

      _messages.add(message);
      notifyListeners();
      
      // Сохраняем в локальное хранилище
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = _messages.map((m) => jsonEncode(m.toJson())).toList();
      await prefs.setStringList('messages', messagesJson);
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }
  
  // Обновление статуса сообщения
  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = ChatMessage(
        id: _messages[index].id,
        text: _messages[index].text,
        senderId: _messages[index].senderId,
        senderName: _messages[index].senderName,
        receiverId: _messages[index].receiverId,
        timestamp: _messages[index].timestamp,
        status: status,
        mediaUrls: _messages[index].mediaUrls,
        isMedia: _messages[index].isMedia,
        mediaType: _messages[index].mediaType,
      );
      notifyListeners();
      
      // Обновляем в хранилище
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = _messages.map((m) => jsonEncode(m.toJson())).toList();
      await prefs.setStringList('messages', messagesJson);
    }
  }
  
  // Получение сообщений с конкретным пользователем
  List<ChatMessage> getMessagesWithPeer(String peerId) {
    return _messages.where((m) => 
      m.senderId == peerId || m.receiverId == peerId
    ).toList();
  }
  
  // Добавление пира в список
  void addPeer(PeerDevice peer) {
    final exists = _peers.any((p) => p.id == peer.id);
    if (!exists) {
      _peers.add(peer);
      notifyListeners();
    }
  }
  
  // Обновление статуса пира
  void updatePeerStatus(String peerId, bool isOnline) {
    final index = _peers.indexWhere((p) => p.id == peerId);
    if (index != -1) {
      _peers[index] = PeerDevice(
        id: _peers[index].id,
        name: _peers[index].name,
        ipAddress: _peers[index].ipAddress,
        port: _peers[index].port,
        lastSeen: DateTime.now(),
        isOnline: isOnline,
      );
      notifyListeners();
    }
  }
  
  // Очистка чата
  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}