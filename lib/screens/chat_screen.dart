import 'package:flutter/material.dart';
// import 'dart:convert';  // <-- УДАЛИТЬ (не используется)
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/network_provider.dart';
import '../models/message.dart';
import '../models/peer.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerIp;
  
  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerIp,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  
  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_isSending) return;
    
    setState(() => _isSending = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
    
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _messageController.text.trim(),
      senderId: authProvider.currentUser!.id,
      senderName: authProvider.currentUser!.name,
      receiverId: widget.peerId,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    
    // Добавляем сообщение локально
    await chatProvider.addMessage(message);
    _messageController.clear();
    _scrollToBottom();
    
    // Отправляем сообщение через сеть
    final peer = PeerDevice(
      id: widget.peerId,
      name: widget.peerName,
      ipAddress: widget.peerIp ?? '',
      port: 8080,
      lastSeen: DateTime.now(),
      isOnline: true,
    );
    
    final status = await networkProvider.sendMessageToPeer(peer, message);
    
    // Обновляем статус
    await chatProvider.updateMessageStatus(
      message.id,
      status,
    );
    
    setState(() => _isSending = false);
  }

  Future<void> _retryMessage(ChatMessage message) async {
    if (_isSending) return;

    setState(() => _isSending = true);

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final networkProvider = Provider.of<NetworkProvider>(context, listen: false);

    await chatProvider.updateMessageStatus(message.id, MessageStatus.sending);

    final peer = PeerDevice(
      id: widget.peerId,
      name: widget.peerName,
      ipAddress: widget.peerIp ?? '',
      port: 8080,
      lastSeen: DateTime.now(),
      isOnline: true,
    );

    final status = await networkProvider.sendMessageToPeer(peer, message);
    await chatProvider.updateMessageStatus(message.id, status);

    setState(() => _isSending = false);
  }
  
  Future<void> _sendMedia() async {
    // TODO: Реализовать отправку изображений (будет добавлено позже)
    _showInfoDialog('Функция отправки медиафайлов в разработке');
  }
  
  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Информация'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final canRetry = isMe && message.status == MessageStatus.failed;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.lightGreen.shade200,
              child: Text(
                message.senderName[0].toUpperCase(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: canRetry ? () => _retryMessage(message) : null,
              child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMe ? Colors.lightGreen : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightGreen.shade800,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.grey.shade500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.status == MessageStatus.delivered
                              ? Icons.done_all
                              : message.status == MessageStatus.sent
                                  ? Icons.check
                                  : message.status == MessageStatus.failed
                                      ? Icons.error_outline
                                      : Icons.access_time,
                          size: 12,
                          color: message.status == MessageStatus.failed
                              ? Colors.red.shade200
                              : (isMe ? Colors.white70 : Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                  if (canRetry)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Нажмите, чтобы отправить еще раз',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade100,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    
    final messages = chatProvider.getMessagesWithPeer(widget.peerId);
    
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.peerName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (widget.peerIp != null)
              Text(
                widget.peerIp!,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        backgroundColor: Colors.lightGreen,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showInfoDialog('P2P соединение\nIP: ${widget.peerIp ?? "Неизвестно"}');
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.lightGreen.shade100,
              Colors.amber.shade100,
            ],
          ),
        ),
        child: Column(
          children: [
            // Список сообщений
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Нет сообщений',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Напишите первое сообщение',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        // ДОБАВИТЬ ЗАЩИТУ ОТ ВЫХОДА ЗА ГРАНИЦЫ
                        if (index >= messages.length) return const SizedBox.shrink();
                        final message = messages[index];
                        final isMe = message.senderId == authProvider.currentUser?.id;
                        return _buildMessageBubble(message, isMe);
                      },
                    ),
            ),
            
            // Поле ввода
            AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom - 8
                    : 0,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.attach_file, color: Colors.lightGreen.shade600),
                        onPressed: _sendMedia,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Сообщение...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.send, color: Colors.lightGreen),
                        onPressed: _isSending ? null : _sendMessage,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}