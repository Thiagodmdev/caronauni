import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/ride_repository.dart';
import '../../models/models.dart';
import '../auth/session_controller.dart';
import '../shared/feedback.dart';

typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

Future<Uint8List?> _pickPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1200,
    maxHeight: 1200,
    imageQuality: 60,
    requestFullMetadata: false,
  );
  return file?.readAsBytes();
}

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key, this.pickPhoto = _pickPhoto});

  final PhotoPicker pickPhoto;

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  Approval? _status;
  Uint8List? _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _userId => context.read<SessionController>().user!.id;

  Future<void> _load() async {
    final repository = context.read<RideRepository>();
    final userId = _userId;
    await runAction(context, () async {
      final status = await repository.licenseStatus(userId);
      if (mounted) setState(() => _status = status);
    });
  }

  Future<void> _pick(ImageSource source) async {
    await runAction(context, () async {
      final photo = await widget.pickPhoto(source);
      if (photo != null && mounted) setState(() => _photo = photo);
    });
  }

  Future<void> _send() async {
    final repository = context.read<RideRepository>();
    final user = context.read<SessionController>().user!;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => repository.sendLicense(user, _photo!),
      success: 'CNH enviada para análise.',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _photo = null;
        _status = Approval.pending;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final theme = Theme.of(context);
    final canSend = status == Approval.missing || status == Approval.refused;
    return Scaffold(
      appBar: AppBar(title: const Text('Minha CNH')),
      body: status == null
          ? Center(
              child: TextButton(
                onPressed: _load,
                child: const Text('Carregando... toque para tentar de novo'),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    switch (status) {
                      Approval.approved => Icons.verified_outlined,
                      Approval.pending => Icons.hourglass_top,
                      _ => Icons.badge_outlined,
                    },
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    switch (status) {
                      Approval.approved => 'CNH aprovada',
                      Approval.pending => 'CNH em análise',
                      Approval.refused => 'CNH não aprovada',
                      Approval.missing => 'Envie a foto da sua CNH',
                    },
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (status) {
                      Approval.approved => 'Você já pode oferecer caronas.',
                      Approval.pending =>
                        'A administração vai conferir a foto antes de você '
                            'oferecer caronas.',
                      _ =>
                        'Só você e a administração veem a foto, que é '
                            'apagada depois da análise.',
                    },
                    textAlign: TextAlign.center,
                  ),
                  if (canSend) ...[
                    const SizedBox(height: 24),
                    if (_photo != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _photo!,
                          height: 220,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Text('Esta imagem não pode ser aberta.'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Tirar foto'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Escolher imagem'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy || _photo == null ? null : _send,
                      child: Text(_busy ? 'Enviando...' : 'Enviar CNH'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
