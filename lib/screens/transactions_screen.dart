import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TxScreenState();
}

class _TxScreenState extends ConsumerState<TransactionsScreen> {
  bool _running = false;
  String? _otpUsed;
  String? _requestId;
  String? _statusLine;

  Future<void> _fireTransaction() async {
    setState(() {
      _running = true;
      _statusLine = 'Signing request with HID Approve OTP...';
    });

    final dio = ref.read(dioProvider);
    try {
      // Intentionally hits a non-routable host. We catch the network
      // error after the interceptor has stamped the headers, so we can
      // still display the OTP the SDK produced.
      await dio.post(
        '/v1/transactions',
        data: {'amount': 42.00, 'currency': 'USD', 'merchant': 'POC Coffee'},
      );
    } on DioException catch (e) {
      final headers = e.requestOptions.headers;
      setState(() {
        _otpUsed = headers['X-HID-OTP'] as String?;
        _requestId = headers['X-HID-Request-Id'] as String?;
        _statusLine = 'Request signed. Network call mocked (no real server).';
      });
    } catch (e) {
      setState(() => _statusLine = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fires a fake POST and shows the HID Approve OTP that '
                'the Dio interceptor attached as X-HID-OTP.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _running ? null : _fireTransaction,
                icon: const Icon(Icons.send),
                label: const Text('Send signed transaction'),
              ),
              const SizedBox(height: 24),
              if (_statusLine != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusLine!),
                        if (_otpUsed != null) ...[
                          const SizedBox(height: 12),
                          _kv('X-HID-OTP', _otpUsed!),
                        ],
                        if (_requestId != null) ...[
                          const SizedBox(height: 4),
                          _kv('X-HID-Request-Id', _requestId!),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: SelectableText(
            v,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
