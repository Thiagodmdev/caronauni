import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/document_store.dart';
import '../../data/ride_repository.dart';
import '../../models/models.dart';
import '../auth/session_controller.dart';
import '../shared/feedback.dart';
import '../shared/reloadable.dart';

typedef _Data = ({
  List<ApprovalRequest> approvals,
  List<LicenseRequest> licenses,
  List<Report> reports,
  List<Fault> faults,
  List<Document> blocked,
  List<MapEntry<String, double>> lowRated,
  UsageReport usage,
});

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _days = 30;

  Future<_Data> _load(RideRepository r) async => (
    approvals: await r.pendingApprovals(),
    licenses: await r.pendingLicenses(),
    reports: await r.openReports(),
    faults: await r.contestedFaults(),
    blocked: await r.blockedUsers(),
    lowRated: await r.lowRated(),
    usage: await r.usage(days: _days),
  );

  @override
  Widget build(BuildContext context) {
    final repository = context.read<RideRepository>();
    final admin = context.read<SessionController>().user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Administração')),
      body: Reloadable<_Data>(
        load: () => _load(repository),
        builder: (context, data, reload) {
          Future<void> act(Future<void> Function() action) async {
            await runAction(context, action, success: 'Concluído.');
            await reload();
          }

          Widget decision({
            required String title,
            required String subtitle,
            required String no,
            required String yes,
            required Future<void> Function() onNo,
            required Future<void> Function() onYes,
            Uint8List? photo,
          }) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                ListTile(title: Text(title), subtitle: Text(subtitle)),
                if (photo != null) _Photo(photo),
                OverflowBar(
                  children: [
                    TextButton(onPressed: () => act(onNo), child: Text(no)),
                    TextButton(onPressed: () => act(onYes), child: Text(yes)),
                  ],
                ),
              ],
            ),
          );

          return [
            const SectionTitle('Cadastros para aprovar'),
            if (data.approvals.isEmpty) const EmptyText('Nenhum pendente.'),
            for (final a in data.approvals)
              decision(
                title: a.name,
                subtitle:
                    '${a.course}\nMatrícula ${a.registration}'
                    '${a.repeated ? '\nAtenção: já usada em outra conta' : ''}',
                no: 'Recusar',
                yes: 'Aprovar',
                onNo: () => repository.resolveApproval(a, approve: false),
                onYes: () => repository.resolveApproval(a, approve: true),
              ),
            const SectionTitle('CNHs para aprovar'),
            if (data.licenses.isEmpty) const EmptyText('Nenhuma pendente.'),
            for (final l in data.licenses)
              decision(
                title: l.name,
                subtitle:
                    'Confira nome, categoria e validade. '
                    'Toque na foto para ampliar.',
                photo: l.photo,
                no: 'Recusar CNH',
                yes: 'Aprovar CNH',
                onNo: () => repository.resolveLicense(l, admin, approve: false),
                onYes: () => repository.resolveLicense(l, admin, approve: true),
              ),
            const SectionTitle('Denúncias'),
            if (data.reports.isEmpty) const EmptyText('Nenhuma em aberto.'),
            for (final r in data.reports)
              decision(
                title: r.toName,
                subtitle: '${r.reason}\nPor ${r.fromName}',
                no: 'Arquivar',
                yes: 'Bloquear',
                onNo: () => repository.resolveReport(r, admin, block: false),
                onYes: () => repository.resolveReport(r, admin, block: true),
              ),
            const SectionTitle('Faltas contestadas'),
            if (data.faults.isEmpty) const EmptyText('Nenhuma em análise.'),
            for (final f in data.faults)
              decision(
                title: f.userName,
                subtitle: f.reason,
                no: 'Retirar',
                yes: 'Manter',
                onNo: () => repository.resolveFault(f, keep: false),
                onYes: () => repository.resolveFault(f, keep: true),
              ),
            const SectionTitle('Avaliação abaixo de 2,5'),
            if (data.lowRated.isEmpty) const EmptyText('Ninguém no momento.'),
            for (final p in data.lowRated)
              ListTile(
                title: Text(p.key),
                trailing: Text(formatRating(p.value)),
              ),
            const SectionTitle('Bloqueados'),
            if (data.blocked.isEmpty) const EmptyText('Ninguém bloqueado.'),
            for (final b in data.blocked)
              ListTile(
                title: Text(b.data['name'] as String),
                trailing: TextButton(
                  onPressed: () => act(() => repository.unblock(b.id)),
                  child: const Text('Desbloquear'),
                ),
              ),
            const SectionTitle('Exemplos para apresentação'),
            const EmptyText(
              'Motoristas fictícios, visíveis para todos, que aceitam pedidos '
              'na hora. Renove no dia da apresentação e remova depois.',
            ),
            OverflowBar(
              children: [
                TextButton(
                  onPressed: () => act(repository.removeSamples),
                  child: const Text('Remover exemplos'),
                ),
                TextButton(
                  onPressed: () => act(repository.addSamples),
                  child: const Text('Adicionar ou renovar'),
                ),
              ],
            ),
            const SectionTitle('Uso do app'),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 dias')),
                ButtonSegment(value: 30, label: Text('30 dias')),
              ],
              selected: {_days},
              onSelectionChanged: (s) {
                _days = s.first;
                reload();
              },
            ),
            ListTile(
              title: const Text('Caronas no período e já marcadas'),
              trailing: Text('${data.usage.rideCount}'),
            ),
            for (final d in data.usage.destinations.take(10))
              ListTile(title: Text(d.key), trailing: Text('${d.value}')),
          ];
        },
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo(this.bytes);

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    Widget image() => Image.memory(
      bytes,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Text('Esta imagem não pode ser aberta.'),
    );
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(child: InteractiveViewer(child: image())),
      ),
      child: SizedBox(height: 180, child: image()),
    );
  }
}
