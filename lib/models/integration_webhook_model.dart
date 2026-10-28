enum ConnectorType {
  lms,
  sis,
  customWebhook;

  String get displayName {
    switch (this) {
      case ConnectorType.lms:
        return 'Learning Management System (LMS)';
      case ConnectorType.sis:
        return 'Student Information System (SIS / ERP)';
      case ConnectorType.customWebhook:
        return 'Custom Enterprise Webhook';
    }
  }
}

class IntegrationConnector {
  final String id;
  final String name;
  final String description;
  final ConnectorType type;
  final String endpointUrl;
  final String authType;
  final List<String> supportedEvents;
  final bool isEnabled;
  final DateTime? lastSyncTime;
  final String lastSyncStatus;

  IntegrationConnector({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.endpointUrl,
    required this.authType,
    required this.supportedEvents,
    this.isEnabled = false,
    this.lastSyncTime,
    this.lastSyncStatus = 'Not Connected',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'endpointUrl': endpointUrl,
    'authType': authType,
    'supportedEvents': supportedEvents,
    'isEnabled': isEnabled,
    'lastSyncTime': lastSyncTime?.toIso8601String(),
    'lastSyncStatus': lastSyncStatus,
  };

  IntegrationConnector copyWith({
    bool? isEnabled,
    DateTime? lastSyncTime,
    String? lastSyncStatus,
    String? endpointUrl,
  }) {
    return IntegrationConnector(
      id: id,
      name: name,
      description: description,
      type: type,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      authType: authType,
      supportedEvents: supportedEvents,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
    );
  }
}

