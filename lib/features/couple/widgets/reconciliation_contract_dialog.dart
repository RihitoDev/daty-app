import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/contract_rule_tile.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/daty_contract_header.dart';
import '../../settings/providers/settings_provider.dart';

class ReconciliationContractDialog extends StatefulWidget {
  final String coupleDocId;
  final bool isProposing;

  const ReconciliationContractDialog({
    super.key,
    required this.coupleDocId,
    this.isProposing = false,
  });

  @override
  State<ReconciliationContractDialog> createState() =>
      _ReconciliationContractDialogState();
}

class _ReconciliationContractDialogState
    extends State<ReconciliationContractDialog> {
  bool _rule1Checked = false;
  bool _rule2Checked = false;
  bool _rule3Checked = false;
  bool _isProcessing = false;

  bool get _allChecked => _rule1Checked && _rule2Checked && _rule3Checked;

  Future<void> _signAction() async {
    if (!_allChecked) return;
    setState(() => _isProcessing = true);

    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (widget.isProposing) {
      final error = await settings.requestReconciliation(widget.coupleDocId);
      if (mounted) {
        if (error != null) {
          CustomSnackBar.showError(context, error);
          setState(() => _isProcessing = false);
        } else {
          CustomSnackBar.showSuccess(
            context,
            'Propuesta firmada y enviada a tu pareja.',
          );
          Navigator.pop(context, true);
        }
      }
    } else {
      final error = await settings.recoverPartnerLink(widget.coupleDocId);
      if (mounted) {
        if (error != null) {
          CustomSnackBar.showError(context, error);
          setState(() => _isProcessing = false);
        } else {
          CustomSnackBar.showSuccess(
            context,
            'Contrato firmado. El vínculo ha sido restaurado exitosamente.',
          );
          Navigator.pop(context, true);
        }
      }
    }
  }

  Future<void> _rejectReconciliation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        actionsOverflowAlignment: OverflowBarAlignment.end,
        actionsOverflowButtonSpacing: 6,
        title: const Text('¿Rechazar propuesta?'),
        content: const Text(
          'Si rechazas la propuesta, la relación continuará en proceso de separación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.cancelReconciliation(widget.coupleDocId);

    if (mounted) {
      CustomSnackBar.showInfo(
          context, 'Propuesta de reconciliación rechazada.');
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;

    return PopScope(
      canPop: !_isProcessing,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DatyContractHeader(
                    title: widget.isProposing
                        ? 'Propuesta de Reconstrucción'
                        : 'Contrato de Reconstrucción',
                    icon: Icons.handshake_outlined,
                    accent: const Color(0xFFE91E63),
                    customTheme: customTheme,
                    isComplete: _allChecked,
                    onClose: () => Navigator.pop(context),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isProposing
                              ? 'Para enviar la propuesta de reconciliación a tu pareja, debes revisar y firmar primero las cláusulas de compromiso:'
                              : 'Tu pareja ha propuesto retomar la relación y firmó el contrato. Para restaurar el vínculo, revisa y firma las cláusulas:',
                          style: TextStyle(
                            color: customTheme.text2,
                            fontSize: 13,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ContractRuleTile(
                          value: _rule1Checked,
                          text:
                              'Escuchar de forma activa y sincera ante cualquier desacuerdo.',
                          accent: const Color(0xFFE91E63),
                          textColor: customTheme.text,
                          onChanged: (val) =>
                              setState(() => _rule1Checked = val),
                        ),
                        ContractRuleTile(
                          value: _rule2Checked,
                          text:
                              'Disposición para sanar el pasado y renovar la confianza día a día.',
                          accent: const Color(0xFFE91E63),
                          textColor: customTheme.text,
                          onChanged: (val) =>
                              setState(() => _rule2Checked = val),
                        ),
                        ContractRuleTile(
                          value: _rule3Checked,
                          text:
                              'Preservar nuestro mapa de aventuras y construir nuevos recuerdos juntos.',
                          accent: const Color(0xFFE91E63),
                          textColor: customTheme.text,
                          onChanged: (val) =>
                              setState(() => _rule3Checked = val),
                        ),
                      ],
                    ),
                    actions: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: customTheme.text2.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isProcessing
                                ? null
                                : (widget.isProposing
                                    ? () => Navigator.pop(context)
                                    : _rejectReconciliation),
                            child: Text(
                              widget.isProposing ? 'Cancelar' : 'Rechazar',
                              style: TextStyle(
                                color: customTheme.text2,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: const Color(0xFFE91E63),
                              disabledBackgroundColor: const Color(0xFFE91E63)
                                  .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isProcessing
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.edit_note_rounded,
                                    color: Colors.white, size: 20),
                            label: Text(
                              widget.isProposing
                                  ? 'Firmar y Enviar'
                                  : 'Firmar y Restaurar',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: (!_allChecked || _isProcessing)
                                ? null
                                : _signAction,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
