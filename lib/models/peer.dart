class PeerDevice {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final DateTime lastSeen;
  final bool isOnline;

  PeerDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
    required this.isOnline,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ipAddress': ipAddress,
    'port': port,
    'lastSeen': lastSeen.toIso8601String(),
    'isOnline': isOnline,
  };
  
  factory PeerDevice.fromJson(Map<String, dynamic> json) => PeerDevice(
    id: json['id'],
    name: json['name'],
    ipAddress: json['ipAddress'],
    port: json['port'],
    lastSeen: DateTime.parse(json['lastSeen']),
    isOnline: json['isOnline'],
  );
}