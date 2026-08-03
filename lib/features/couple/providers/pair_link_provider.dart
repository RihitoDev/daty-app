import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class PairLinkProvider extends ChangeNotifier {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _pendingCode;
  bool _loginRequested = false;

  String? get pendingCode => _pendingCode;
  bool get loginRequested => _loginRequested;

  Future<void> initialize() async {
    _handleUri(await _appLinks.getInitialLink());
    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error) {
        debugPrint('No se pudo procesar el enlace de Daty: $error');
      },
    );
  }

  String? consumePendingCode() {
    final code = _pendingCode;
    _pendingCode = null;
    return code;
  }

  void consumeLoginRequest() {
    _loginRequested = false;
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;

    if (uri.scheme == 'daty' && uri.host == 'login') {
      if (_loginRequested) return;
      _loginRequested = true;
      notifyListeners();
      return;
    }

    String? code;
    if (uri.scheme == 'daty' && uri.host == 'pair') {
      code = uri.queryParameters['code'];
    } else if (uri.scheme == 'https' &&
        uri.host == 'datty-app.web.app' &&
        uri.path == '/pair') {
      code = uri.queryParameters['code'];
    } else if (uri.scheme == 'https' &&
        uri.host == 'darklife22.github.io' &&
        uri.path.startsWith('/Daty-landing')) {
      code = uri.queryParameters['pairCode'];
    }

    final normalizedCode = code?.trim().toUpperCase();
    if (normalizedCode == null ||
        !RegExp(r'^[A-Z]{3}[0-9]{3}$').hasMatch(normalizedCode)) {
      return;
    }

    if (_pendingCode == normalizedCode) return;
    _pendingCode = normalizedCode;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
