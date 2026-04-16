enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String receiverId;
  final DateTime timestamp;
  final MessageStatus status;
  final List<String>? mediaUrls;
  final bool isMedia;
  final String? mediaType;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.timestamp,
    required this.status,
    this.mediaUrls,
    this.isMedia = false,
    this.mediaType,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'senderId': senderId,
    'senderName': senderName,
    'receiverId': receiverId,
    'timestamp': timestamp.toIso8601String(),
    'status': status.index,
    'mediaUrls': mediaUrls,
    'isMedia': isMedia,
    'mediaType': mediaType,
  };
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    text: json['text'],
    senderId: json['senderId'],
    senderName: json['senderName'],
    receiverId: json['receiverId'],
    timestamp: DateTime.parse(json['timestamp']),
    status: MessageStatus.values[json['status']],
    mediaUrls: json['mediaUrls']?.cast<String>(),
    isMedia: json['isMedia'] ?? false,
    mediaType: json['mediaType'],
  );
}