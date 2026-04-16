class LocalUser {
  final String id;
  final String name;
  final String deviceId;
  final String publicKey;
  final DateTime createdAt;

  LocalUser({
    required this.id,
    required this.name,
    required this.deviceId,
    required this.publicKey,
    required this.createdAt,
  });
  
  static LocalUser empty() => LocalUser(
    id: '',
    name: 'Гость',
    deviceId: '',
    publicKey: '',
    createdAt: DateTime.now(),
  );
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'deviceId': deviceId,
    'publicKey': publicKey,
    'createdAt': createdAt.toIso8601String(),
  };
  
  factory LocalUser.fromJson(Map<String, dynamic> json) => LocalUser(
    id: json['id'],
    name: json['name'],
    deviceId: json['deviceId'],
    publicKey: json['publicKey'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}