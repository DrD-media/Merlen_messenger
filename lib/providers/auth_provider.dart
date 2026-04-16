import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  LocalUser? _currentUser;
  
  LocalUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  
  // Генерация уникального ID устройства
  String _generateDeviceId() {
    return sha256.convert(utf8.encode(DateTime.now().millisecondsSinceEpoch.toString())).toString().substring(0, 16);
  }
  
  // Генерация публичного ключа (упрощённая версия)
  String _generatePublicKey() {
    return sha256.convert(utf8.encode('${DateTime.now().millisecondsSinceEpoch}_${Random().nextDouble()}')).toString();
  }
  
  // Регистрация пользователя
  Future<bool> register(String name) async {
    if (name.isEmpty) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final userId = _generateDeviceId();
      final deviceId = _generateDeviceId();
      final publicKey = _generatePublicKey();
      
      final user = LocalUser(
        id: userId,
        name: name,
        deviceId: deviceId,
        publicKey: publicKey,
        createdAt: DateTime.now(),
      );
      
      // Сохраняем пользователя
      await prefs.setString('user_data', jsonEncode(user.toJson()));
      await prefs.setBool('is_logged_in', true);
      
      _currentUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }
  
  // Проверка авторизации
  Future<bool> checkIfLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      
      if (isLoggedIn) {
        final userData = prefs.getString('user_data');
        if (userData != null) {
          final json = jsonDecode(userData);
          _currentUser = LocalUser.fromJson(json);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Выход
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    //await prefs.clear(); // Выход - НЕ УДАЛЯЕМ СООБЩЕНИЯ!
    await prefs.remove('user_data');
    await prefs.remove('is_logged_in');
    _currentUser = null;
    notifyListeners();
  }
}