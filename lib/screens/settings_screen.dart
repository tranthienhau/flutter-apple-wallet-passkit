import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _biometricEnabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = ref.read(secureStorageServiceProvider);
    _nameController.text = await storage.readCardholderName() ?? 'HAU TRAN';
    _biometricEnabled = await storage.readBiometricEnabled();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveName() async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.writeCardholderName(_nameController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cardholder name saved.')),
      );
    }
  }

  Future<void> _toggleBiometric(bool next) async {
    if (next) {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      if (!canCheck) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometrics not available.')),
          );
        }
        return;
      }
      try {
        final ok = await auth.authenticate(
          localizedReason: 'Enable Face ID / Touch ID for the wallet.',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (!ok) return;
      } catch (_) {
        return;
      }
    }
    final storage = ref.read(secureStorageServiceProvider);
    await storage.writeBiometricEnabled(next);
    if (mounted) setState(() => _biometricEnabled = next);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Cardholder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Name on card',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _saveName,
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Require biometrics'),
              subtitle: const Text(
                'Prompt Face ID / Touch ID before sensitive actions.',
              ),
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
            ),
          ],
        ),
      ),
    );
  }
}
