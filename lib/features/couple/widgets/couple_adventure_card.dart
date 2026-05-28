import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'pairing_dialog.dart';
import 'contract_dialog.dart';
import '../../shared/screens/adventure_map.dart';

class CoupleAdventureCard extends StatefulWidget {
  const CoupleAdventureCard({super.key});

  @override
  State<CoupleAdventureCard> createState() => _CoupleAdventureCardState();
}

class _CoupleAdventureCardState extends State<CoupleAdventureCard> {
  Map<String, dynamic>? _coupleData;
  String _partnerName = 'tu pareja';
  bool _isLoading = true;
  StreamSubscription? _coupleSub;
  StreamSubscription? _partnerSub;
  bool _hasShownContractDialog = false;
  String? _currentPartnerId; // Para detectar cuando cambia el partner

  @override
  void initState() {
    super.initState();
    // La configuración inicial se hará en didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = authProvider.userData;
    final newPartnerId = userData?['partnerId'] as String?;

    // Si el partnerId cambió (ej. se acaba de vincular), reiniciamos los listeners
    if (newPartnerId != _currentPartnerId) {
      _currentPartnerId = newPartnerId;
      _cancelSubscriptions(); // Limpiamos listeners viejos

      if (_currentPartnerId != null) {
        _setupListeners(authProvider.user!.uid, _currentPartnerId!);
      } else {
        // Si no tiene pareja, aseguramos que deje de cargar
        if (mounted) {
          setState(() {
            _isLoading = false;
            _coupleData = null;
          });
        }
      }
    }
  }

  void _cancelSubscriptions() {
    _coupleSub?.cancel();
    _partnerSub?.cancel();
    _coupleSub = null;
    _partnerSub = null;
  }

  void _setupListeners(String myUid, String partnerId) {
    if (!mounted) return;
    setState(() => _isLoading = true); // Mostramos carga mientras busca el nuevo doc

    String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';

    // Escuchar cambios en el documento de la pareja
    _coupleSub = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId).snapshots().listen(
      (snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _coupleData = snapshot.data()!;
            _isLoading = false;
          });
          _checkContractStatus(myUid, partnerId, coupleDocId);
        } else if (!snapshot.exists && mounted) {
          // El documento aún no se crea o fue borrado
          setState(() {
            _coupleData = null;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint("🔥 Error leyendo couples_progress: $error");
        if (mounted) setState(() => _isLoading = false);
      }
    );

    // Escuchar nombre de la pareja
    _partnerSub = FirebaseFirestore.instance.collection('users').doc(partnerId).snapshots().listen(
      (snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _partnerName = snapshot.data()?['username'] ?? 'tu pareja';
          });
        }
      },
      onError: (error) {
        debugPrint("🔥 Error leyendo partner data: $error");
      }
    );
  }

  void _checkContractStatus(String myUid, String partnerId, String coupleDocId) {
    if (_coupleData == null) return;
    
    bool isUser1 = myUid.compareTo(partnerId) < 0;
    bool iSigned = isUser1 ? (_coupleData?['contractSignedUser1'] ?? false) : (_coupleData?['contractSignedUser2'] ?? false);

    if (!iSigned && !_hasShownContractDialog) {
      _showContractDialog(myUid, partnerId, coupleDocId);
    }
  }

  void _showContractDialog(String myUid, String partnerUid, String coupleDocId) {
    if (_hasShownContractDialog) return;
    _hasShownContractDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContractDialog(myUid: myUid, partnerUid: partnerUid, coupleDocId: coupleDocId),
    ).then((_) {
      _hasShownContractDialog = false;
    });
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData;
    final bool hasPartner = userData != null && userData.containsKey('partnerId') && userData['partnerId'] != null;

    if (!hasPartner) {
      return _buildPremiumCard(
        title: 'Aventura en pareja', 
        subtitle: 'Vincúlate con alguien', 
        gradientColors: const [Color(0xFFF48FB1), Color(0xFFD81B60)], 
        icon: Icons.favorite_border_rounded, 
        onTap: () {
          if (authProvider.user != null) {
            showDialog(context: context, builder: (context) => PairingDialog(myUid: authProvider.user!.uid));
          }
        }
      );
    }

    if (_isLoading || _coupleData == null) {
      return _buildPremiumCard(title: 'Cargando...', subtitle: '', gradientColors: [Colors.grey, Colors.grey.shade700], icon: Icons.hourglass_empty, onTap: () {});
    }

    final String myUid = authProvider.user!.uid;
    final String partnerId = userData['partnerId'];
    String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';

    bool isUser1 = myUid.compareTo(partnerId) < 0;
    bool iSigned = isUser1 ? (_coupleData?['contractSignedUser1'] ?? false) : (_coupleData?['contractSignedUser2'] ?? false);
    bool partnerSigned = isUser1 ? (_coupleData?['contractSignedUser2'] ?? false) : (_coupleData?['contractSignedUser1'] ?? false);

    if (!iSigned) {
      return _buildPremiumCard(
        title: 'Aventura en pareja', 
        subtitle: 'Firma el contrato con $_partnerName', 
        gradientColors: const [Color(0xFFFFB74D), Color(0xFFF57C00)], 
        icon: Icons.history_edu, 
        onTap: () => _showContractDialog(myUid, partnerId, coupleDocId),
      );
    }

    if (iSigned && !partnerSigned) {
      return _buildPremiumCard(
        title: 'Aventura en pareja', 
        subtitle: 'Esperando firma de $_partnerName', 
        gradientColors: const [Color(0xFF90A4AE), Color(0xFF546E7A)], 
        icon: Icons.hourglass_top, 
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Esperando que $_partnerName firme el contrato...')),
          );
        },
      );
    }

    // ¡Vinculados y listos!
    return _buildPremiumCard(
      title: 'Aventura en pareja', 
      subtitle: 'Nuestra aventura junto a $_partnerName', 
      gradientColors: const [Color(0xFFF06292), Color(0xFFC2185B)], 
      icon: Icons.favorite, 
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdventureMap(
                    mode: 'couple',
                    themeColor: Color(0xFFC2185B),
                    pathColor: Color(0xFFF48FB1),
                    totalNodes: 50,
                    headerTitle: 'Nuestro Viaje',
                  )))
    );
  }

  Widget _buildPremiumCard({
    required String title, 
    required String subtitle, 
    required List<Color> gradientColors, 
    required IconData icon, 
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), 
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: gradientColors.last.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8), spreadRadius: 2)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14), 
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle), 
              child: Icon(icon, size: 40, color: Colors.white)
            ),
            const SizedBox(width: 25),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))])), 
                  const SizedBox(height: 6), 
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 15, fontWeight: FontWeight.w600))
                ]
              )
            ),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 28)
          ],
        ),
      ),
    );
  }
}