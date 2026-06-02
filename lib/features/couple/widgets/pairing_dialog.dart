import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

class PairingDialog extends StatefulWidget {
  final String myUid;
  const PairingDialog({super.key, required this.myUid});

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _codeController = TextEditingController();
  
  bool _isLinking = false;
  bool _isShowingMyCode = true;
  late String _myCode;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _generateAndSaveCode();
    _listenForPartnerLink();
  }

  void _generateAndSaveCode() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    math.Random rnd = math.Random();
    
    String randomLetters = String.fromCharCodes(Iterable.generate(3, (_) => letters.codeUnitAt(rnd.nextInt(letters.length))));
    String randomNumbers = String.fromCharCodes(Iterable.generate(3, (_) => numbers.codeUnitAt(rnd.nextInt(numbers.length))));
    
    List<String> codeChars = ('$randomLetters$randomNumbers').split('');
    codeChars.shuffle(rnd);
    _myCode = codeChars.join();

    _firestore.collection('users').doc(widget.myUid).set({'pairingCode': _myCode}, SetOptions(merge: true));
  }

  void _listenForPartnerLink() {
    _subscription = _firestore.collection('users').doc(widget.myUid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data();
        if (data != null && data.containsKey('partnerId') && data['partnerId'] != null) {
          if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      }
    });
  }

  void _handleLink() async {
    if (_codeController.text.length < 6) return;
    if (mounted) setState(() => _isLinking = true);

    try {
      final codeEntered = _codeController.text.toUpperCase();

      final querySnapshot = await _firestore.collection('users')
          .where('pairingCode', isEqualTo: codeEntered)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Codigo no encontrado');
      }

      final partnerUid = querySnapshot.docs.first.id;

      if (partnerUid == widget.myUid) {
        throw Exception('No puedes vincularte a ti mismo');
      }

      String coupleDocId = widget.myUid.compareTo(partnerUid) < 0 
          ? '${widget.myUid}_$partnerUid' 
          : '${partnerUid}_${widget.myUid}';

      await _firestore.runTransaction((transaction) async {
        
        final myDocRef = _firestore.collection('users').doc(widget.myUid);
        final partnerDocRef = _firestore.collection('users').doc(partnerUid);
        final coupleDocRef = _firestore.collection('couples_progress').doc(coupleDocId);

        final myDoc = await transaction.get(myDocRef);
        final partnerDoc = await transaction.get(partnerDocRef);

        if (myDoc.data()?['partnerId'] != null) {
          throw Exception('Tu ya estas vinculado');
        }
        if (partnerDoc.data()?['partnerId'] != null) {
          throw Exception('Esta persona ya esta vinculada');
        }

        transaction.set(coupleDocRef, {
          'user1': widget.myUid.compareTo(partnerUid) < 0 ? widget.myUid : partnerUid,
          'user2': widget.myUid.compareTo(partnerUid) < 0 ? partnerUid : widget.myUid, 
          'fechaVinculacion': FieldValue.serverTimestamp(), 
          'xpPareja': 0, 
          'nivelPareja': 1,
          'contractSignedUser1': false,
          'contractSignedUser2': false
        });

        transaction.update(myDocRef, {'partnerId': partnerUid, 'pairingCode': FieldValue.delete()});
        transaction.update(partnerDocRef, {'partnerId': widget.myUid, 'pairingCode': FieldValue.delete()});
      });

    } catch (e) {
      if (mounted) {
        setState(() => _isLinking = false);
        String errorMsg = 'Error al vincular';
        if (e.toString().contains('Codigo no encontrado')) {
          errorMsg = 'Codigo no encontrado';
        } else if (e.toString().contains('ya esta vinculada')) {
          errorMsg = 'Esta persona ya tiene pareja';
        } else if (e.toString().contains('ya estas vinculado')) {
          errorMsg = 'Tu ya estas vinculado';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _firestore.collection('users').doc(widget.myUid).set({'pairingCode': FieldValue.delete()}, SetOptions(merge: true));
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      backgroundColor: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(25.0, 30.0, 25.0, 25.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, color: Color(0xFFFF4B12), size: 60),
                const SizedBox(height: 15),
                const Text('Una aventura de dos\nesta por comenzar', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF9C27B0))),
                const SizedBox(height: 25),

                if (_isShowingMyCode) ...[
                  const Text('Comparte tu codigo:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(color: const Color(0xFFF1E5F5), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFCE93D8), width: 2)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_myCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3)),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Color(0xFF9C27B0)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _myCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: const [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text('Codigo copiado')]),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              )
                            );
                          },
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C27B0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                      onPressed: () => setState(() => _isShowingMyCode = false),
                      child: const Text('Tengo un codigo', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else ...[
                  const Text('Ingresa el codigo de tu pareja:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController, textCapitalization: TextCapitalization.characters, textAlign: TextAlign.center, maxLength: 6, autofocus: true,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3),
                    decoration: InputDecoration(hintText: 'ABC123', counterText: "", filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4B12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                      onPressed: _isLinking ? null : _handleLink,
                      child: _isLinking 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Vincular', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isShowingMyCode = true),
                    child: const Text('Ver mi codigo de nuevo', style: TextStyle(color: Colors.grey)),
                  )
                ],
              ],
            ),
          ),
          Positioned(
            top: 0, right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}