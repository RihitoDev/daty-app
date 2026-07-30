import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../providers/couple_provider.dart';
import '../providers/pair_invitation_controller.dart';
import '../services/pair_invitation_service.dart';

class PairingDialog extends StatefulWidget {
  const PairingDialog({
    super.key,
    this.initialCode,
  });

  final String? initialCode;

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog> {
  final TextEditingController _codeController = TextEditingController();
  late final PairInvitationController _invitationController;

  bool _enteringCode = false;
  bool _codeIsValid = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final initialCode = widget.initialCode?.trim().toUpperCase();
    if (initialCode != null &&
        RegExp(r'^[A-Z]{3}[0-9]{3}$').hasMatch(initialCode)) {
      _codeController.text = initialCode;
      _enteringCode = true;
      _codeIsValid = true;
    }

    _invitationController = PairInvitationController(PairInvitationService())
      ..addListener(_onInvitationChanged)
      ..loadInvitation();
  }

  void _onInvitationChanged() {
    if (mounted) setState(() {});
  }

  void _close({bool linked = false}) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(linked);
  }

  Future<void> _shareCode() async {
    final invitation = _invitationController.invitation;
    if (invitation == null || !_invitationController.canShare) return;

    final box = context.findRenderObject() as RenderBox?;
    final invitationUrl = Uri.https(
      'darklife22.github.io',
      '/Daty-landing/',
      {'pairCode': invitation.code},
    );
    await SharePlus.instance.share(
      ShareParams(
        text: '¡Quiero vincularme contigo en Daty! 💜\n\n'
            'Usa este código:\n${invitation.code}\n\n'
            'Abre la invitación:\n$invitationUrl\n\n'
            'La invitación vence en 15 minutos.',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      CustomSnackBar.showSuccess(context, 'Código copiado');
    }
  }

  Future<void> _acceptCode() async {
    if (!_codeIsValid) return;
    FocusScope.of(context).unfocus();
    final linked =
        await _invitationController.acceptInvitation(_codeController.text);
    if (linked && mounted) _close(linked: true);
  }

  String _remainingLabel(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _invitationController
      ..removeListener(_onInvitationChanged)
      ..dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    final hasPartner = context.watch<CoupleProvider>().hasPartner;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final horizontalPadding =
        MediaQuery.sizeOf(context).width >= 600 ? 32.0 : 22.0;

    if (hasPartner && !_closing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close(linked: true));
    }

    return PopScope(
      canPop: !_closing,
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            decoration: BoxDecoration(
              color: customTheme.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(
                top: BorderSide(
                  color: customTheme.primary.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                10,
                horizontalPadding,
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: customTheme.muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Cerrar',
                      onPressed: _close,
                      icon: Icon(
                        Icons.close_rounded,
                        color: customTheme.muted,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/images/mascot.png',
                    height: keyboardHeight > 0 ? 60 : 92,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.favorite_rounded,
                      size: 64,
                      color: customTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _enteringCode
                        ? 'Ingresa tu código'
                        : 'Vincúlate con alguien',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: customTheme.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _enteringCode
                        ? 'Escribe el código que te compartió la otra persona.'
                        : 'Comparte este código con la persona con la que quieres vivir aventuras.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: customTheme.text2,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _enteringCode
                        ? _buildCodeEntry(customTheme)
                        : _buildInvitation(customTheme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvitation(AppCustomTheme customTheme) {
    final status = _invitationController.status;
    final invitation = _invitationController.invitation;

    if (status == PairInvitationStatus.loading) {
      return _buildStatus(
        customTheme,
        key: const ValueKey('loading'),
        label: 'Generando código...',
        loading: true,
      );
    }

    if (status == PairInvitationStatus.error || invitation == null) {
      return _buildStatus(
        customTheme,
        key: const ValueKey('error'),
        label: _invitationController.errorMessage ??
            'No se pudo generar el código. Inténtalo nuevamente.',
        buttonLabel: 'Reintentar',
        onPressed: _invitationController.loadInvitation,
      );
    }

    if (status == PairInvitationStatus.expired) {
      return _buildStatus(
        customTheme,
        key: const ValueKey('expired'),
        icon: Icons.timer_off_outlined,
        label: 'Esta invitación venció',
        buttonLabel: 'Generar nuevo código',
        onPressed: _invitationController.loadInvitation,
      );
    }

    return Column(
      key: const ValueKey('invitation'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: customTheme.primaryLight.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: customTheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;

              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 40 : 52,
                      ),
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              invitation.code,
                              semanticsLabel: 'Código ${invitation.code}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: customTheme.text,
                                fontSize: compact ? 29 : 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: compact ? 4 : 7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'La invitación vence en '
                            '${_remainingLabel(_invitationController.remaining)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: customTheme.text2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      tooltip: 'Copiar código',
                      onPressed: () => _copyCode(invitation.code),
                      icon: Icon(
                        Icons.copy_rounded,
                        color: customTheme.primary,
                        size: 21,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            customTheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _invitationController.canShare ? _shareCode : null,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Compartir código'),
            style: ElevatedButton.styleFrom(
              backgroundColor: customTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            _invitationController.clearError();
            setState(() => _enteringCode = true);
          },
          child: Text(
            'Tengo un código',
            style: TextStyle(
              color: customTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeEntry(AppCustomTheme customTheme) {
    final isValidating =
        _invitationController.status == PairInvitationStatus.validating;

    return Column(
      key: const ValueKey('code-entry'),
      children: [
        TextField(
          controller: _codeController,
          autofocus: true,
          enabled: !isValidating,
          maxLength: 6,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(6),
            _UpperCaseTextFormatter(),
          ],
          onChanged: (value) {
            final valid = RegExp(r'^[A-Z]{3}[0-9]{3}$').hasMatch(value);
            _invitationController.clearError();
            if (valid != _codeIsValid) setState(() => _codeIsValid = valid);
          },
          onSubmitted: (_) {
            if (_codeIsValid && !isValidating) _acceptCode();
          },
          style: TextStyle(
            color: customTheme.text,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'ABC123',
            hintStyle: TextStyle(
              color: customTheme.muted.withValues(alpha: 0.55),
            ),
            filled: true,
            fillColor: customTheme.primaryLight.withValues(alpha: 0.35),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: customTheme.muted.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: customTheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
        if (_invitationController.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _invitationController.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _codeIsValid && !isValidating ? _acceptCode : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: customTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: isValidating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Vincularme'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: isValidating
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  _invitationController.clearError();
                  setState(() => _enteringCode = false);
                },
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Volver'),
          style: TextButton.styleFrom(foregroundColor: customTheme.text2),
        ),
      ],
    );
  }

  Widget _buildStatus(
    AppCustomTheme customTheme, {
    required Key key,
    required String label,
    IconData? icon,
    bool loading = false,
    String? buttonLabel,
    VoidCallback? onPressed,
  }) {
    return Column(
      key: key,
      children: [
        if (loading)
          CircularProgressIndicator(color: customTheme.primary)
        else
          Icon(
            icon ?? Icons.cloud_off_rounded,
            color: customTheme.primary,
            size: 44,
          ),
        const SizedBox(height: 14),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: customTheme.text2,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (buttonLabel != null) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: customTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
