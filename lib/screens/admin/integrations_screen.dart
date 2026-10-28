import 'package:flutter/material.dart';
import '../../models/integration_webhook_model.dart';
import '../../services/integration_service.dart';

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  final IntegrationService _integrationService = IntegrationService();
  late List<IntegrationConnector> _connectors;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _connectors = _integrationService.getDefaultConnectors();
  }

  void _toggleConnector(int idx, bool val) async {
    setState(() {
      _connectors[idx] = _connectors[idx].copyWith(isEnabled: val);
    });
    await _integrationService.toggleConnector(_connectors[idx].id, val);
  }

  Future<void> _testDispatch(IntegrationConnector connector) async {
    setState(() => _isTesting = true);

    final result = await _integrationService.testDispatchWebhook(
      connector: connector,
      courseId: 'CS301',
      courseName: 'CS-301: Advanced Algorithms',
    );

    if (mounted) {
      setState(() => _isTesting = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${connector.name} Sync',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Delivered over TLS 1.3 • HTTP ${result.statusCode} OK',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Dispatched JSON Payload:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: Text(
                    result.formattedPayload,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('LMS & SIS/ERP Integrations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enterprise Sync Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hub_outlined, color: Colors.white, size: 32),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enterprise Interoperability Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text(
                          'Synchronize attendance events in real time with Google Classroom, Canvas LMS, and PowerSchool SIS.',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Active Connectors & Webhooks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _connectors.length,
              itemBuilder: (ctx, idx) {
                final conn = _connectors[idx];

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_getConnectorIcon(conn.type), color: const Color(0xFF6366F1), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(conn.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(conn.type.displayName, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                ],
                              ),
                            ),
                            Switch(
                              value: conn.isEnabled,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) => _toggleConnector(idx, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(conn.description, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.3)),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Endpoint: ${conn.endpointUrl}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              const SizedBox(height: 4),
                              Text('Security: ${conn.authType}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                              const SizedBox(height: 4),
                              Text('Status: ${conn.lastSyncStatus}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.send_rounded, size: 14),
                            label: const Text('Test Webhook Dispatch'),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: _isTesting ? null : () => _testDispatch(conn),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getConnectorIcon(ConnectorType type) {
    switch (type) {
      case ConnectorType.lms:
        return Icons.school_outlined;
      case ConnectorType.sis:
        return Icons.dns_outlined;
      case ConnectorType.customWebhook:
        return Icons.webhook;
    }
  }
}

