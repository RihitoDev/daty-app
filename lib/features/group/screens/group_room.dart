import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/group_provider.dart';
import 'group_adventure_screen.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class GroupRoom extends StatefulWidget {
  final String groupCode;
  const GroupRoom({super.key, required this.groupCode});

  @override
  State<GroupRoom> createState() => _GroupRoomState();
}

class _GroupRoomState extends State<GroupRoom> {
  StreamSubscription<DocumentSnapshot>? _groupSubscription;
  List<dynamic> _members = [];
  String _creatorId = '';
  int _maxMembers = 12;
  String _status = 'waiting';
  int _activeAdventureId = 0;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _listenToGroup();
  }

  void _listenToGroup() {
    _groupSubscription = FirebaseFirestore.instance.collection('groups').doc(widget.groupCode).snapshots().listen((doc) {
      if (!doc.exists) {
        if (mounted) {
          CustomSnackBar.showError(context, 'El grupo fue disuelto.');
          // Solo llamamos leaveGroup, no hacemos pop. El provider actualizará la UI solo.
          Provider.of<GroupProvider>(context, listen: false).leaveGroup();
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      
      setState(() {
        _members = data['members'] ?? [];
        _creatorId = data['creatorId'] ?? '';
        _maxMembers = data['maxMembers'] ?? 12;
        _status = data['status'] ?? 'waiting';
        _activeAdventureId = data['activeAdventureId'] ?? 0;
      });

      if (_status == 'active' && !_isNavigating) {
        _isNavigating = true;
        _navigateToAdventure();
      }
    });
  }

  Future<void> _navigateToAdventure() async {
    try {
      final adventureSnap = await FirebaseFirestore.instance.collection('adventures').where('number', isEqualTo: _activeAdventureId).limit(1).get();
      if (adventureSnap.docs.isNotEmpty && mounted) {
        final adventureData = adventureSnap.docs.first.data();
        
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => GroupAdventureScreen(
            adventureData: adventureData, 
            groupCode: widget.groupCode, 
            members: List<String>.from(_members),
          ))
        ).then((_) {
          if (mounted) setState(() => _isNavigating = false);
        });
        
      } else {
        _isNavigating = false;
      }
    } catch (e) {
      _isNavigating = false;
    }
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProvider.user!.uid;
    final bool isCreator = myUid == _creatorId;

    return Scaffold(
        backgroundColor: const Color(0xFFF3E5F5),
        appBar: AppBar(
          title: const Text('Sala de Espera', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF8E24AA),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await Provider.of<GroupProvider>(context, listen: false).leaveGroup();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () async {
                await Provider.of<GroupProvider>(context, listen: false).leaveGroup();
              },
            ),
          ],
        ),
        body: _status == 'active' 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA))) 
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    child: Column(
                      children: [
                        const Text('Código del Grupo:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Text(widget.groupCode, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 5, color: Color(0xFF8E24AA))),
                        const SizedBox(height: 15),
                        
                        if (isCreator)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Límite del grupo:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                              const SizedBox(width: 10),
                              DropdownButton<int>(
                                value: _maxMembers,
                                underline: Container(),
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8E24AA)),
                                items: List.generate(11, (index) => index + 2).map((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text('$value personas', style: const TextStyle(color: Color(0xFF8E24AA), fontWeight: FontWeight.bold)),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    Provider.of<GroupProvider>(context, listen: false).updateMaxMembers(widget.groupCode, newValue);
                                  }
                                },
                              ),
                            ],
                          )
                        else
                          Text('${_members.length}/$_maxMembers Aventureros', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(_members[index]).get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData) return const ListTile(title: Text('Cargando...'));
                            final userData = userSnap.data!.data() as Map<String, dynamic>?;
                            final name = userData?['username'] ?? 'Aventurero';
                            final isMe = _members[index] == myUid;
                            
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: _members[index] == _creatorId ? Colors.amber : const Color(0xFF8E24AA), child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                title: Text(isMe ? '$name (Tú)' : name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: _members[index] == _creatorId ? const Icon(Icons.star, color: Colors.amber) : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  if (isCreator)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _members.length >= 2 ? Colors.green : Colors.grey,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _members.length >= 2 ? () async {
                        final provider = Provider.of<GroupProvider>(context, listen: false);
                        await provider.startExpedition(widget.groupCode);
                      } : null,
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text('Iniciar Expedición', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
      );
  }
}