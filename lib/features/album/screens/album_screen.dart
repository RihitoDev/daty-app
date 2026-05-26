import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/album_memory.dart';
import '../services/album_service.dart';
import '../widgets/memory_card.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Álbum de Recuerdos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF9C27B0),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            isScrollable: true,
            tabs: [
              Tab(text: 'Todos', icon: Icon(Icons.auto_stories)),
              Tab(text: 'Solo', icon: Icon(Icons.backpack_outlined)),
              Tab(text: 'Pareja', icon: Icon(Icons.favorite_outline)),
              Tab(text: 'Grupo', icon: Icon(Icons.groups_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AllAlbumList(),
            _SoloAlbumList(),
            _CoupleAlbumList(),
            _GroupAlbumList(),
          ],
        ),
      ),
    );
  }
}

class _AllAlbumList extends StatefulWidget {
  const _AllAlbumList();

  @override
  State<_AllAlbumList> createState() => _AllAlbumListState();
}

class _AllAlbumListState extends State<_AllAlbumList> with AutomaticKeepAliveClientMixin {
  late Future<List<AlbumMemory>> _dataFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<List<AlbumMemory>> _fetchData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProvider.user!.uid;
    final myName = authProvider.userData?['username'] ?? 'Yo';
    
    String? partnerId = authProvider.userData?['partnerId'];
    String partnerName = 'Pareja';
    bool isUser1 = false;
    
    if (partnerId != null) {
      isUser1 = myUid.compareTo(partnerId) < 0;
      final partnerDoc = await FirebaseFirestore.instance.collection('users').doc(partnerId).get();
      if (partnerDoc.exists) partnerName = partnerDoc.data()?['username'] ?? 'Pareja';
    } else {
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      if (myDoc.exists) {
        partnerId = myDoc.data()?['partnerId'];
        if (partnerId != null) {
          isUser1 = myUid.compareTo(partnerId) < 0;
          final partnerDoc = await FirebaseFirestore.instance.collection('users').doc(partnerId).get();
          if (partnerDoc.exists) partnerName = partnerDoc.data()?['username'] ?? 'Pareja';
        }
      }
    }

    return AlbumService.fetchAllMemories(
      myUid: myUid, 
      myName: myName, 
      partnerId: partnerId, 
      partnerName: partnerName, 
      isUser1: isUser1
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<AlbumMemory>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0)));
        
        if (snapshot.hasError) {
          debugPrint('ALL ALBUM ERROR: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('Error al cargar los recuerdos:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Aún no tienes recuerdos guardados', style: TextStyle(color: Colors.grey)));
        
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) => MemoryCard(memory: snapshot.data![index]),
          ),
        );
      },
    );
  }
}

class _SoloAlbumList extends StatefulWidget {
  const _SoloAlbumList();

  @override
  State<_SoloAlbumList> createState() => _SoloAlbumListState();
}

class _SoloAlbumListState extends State<_SoloAlbumList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('solo_memories').where('userId', isEqualTo: myUid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Aún no tienes aventuras solitarias', style: TextStyle(color: Colors.grey)));
        
        List<AlbumMemory> memories = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return AlbumMemory(
            type: 'Solo', title: data['adventure_title'] ?? 'Aventura', emoji: '🧘‍♂️',
            date: AlbumService.parseDate(data['timestamp']),
            reviews: [if (data['review'] != null && data['review'].toString().isNotEmpty) data['review']],
            photoUrls: List<String>.from(data['photos'] ?? []),
          );
        }).toList();

        memories.sort((a, b) => b.date.compareTo(a.date));
        
        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: memories.length,
          itemBuilder: (context, index) => MemoryCard(memory: memories[index]),
        );
      },
    );
  }
}

class _CoupleAlbumList extends StatefulWidget {
  const _CoupleAlbumList();

  @override
  State<_CoupleAlbumList> createState() => _CoupleAlbumListState();
}

class _CoupleAlbumListState extends State<_CoupleAlbumList> with AutomaticKeepAliveClientMixin {
  String _partnerName = 'Pareja';
  bool _isUser1 = true;
  String _myName = 'Yo';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProvider.user!.uid;
    final partnerId = authProvider.userData?['partnerId'];
    _myName = authProvider.userData?['username'] ?? 'Yo';
    
    if (partnerId != null) {
      _isUser1 = myUid.compareTo(partnerId) < 0;
      final doc = await FirebaseFirestore.instance.collection('users').doc(partnerId).get();
      if (doc.exists && mounted) {
        setState(() {
          _partnerName = doc.data()?['username'] ?? 'Pareja';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProvider.user!.uid;
    final partnerId = authProvider.userData?['partnerId'];

    if (partnerId == null) return const Center(child: Text('Vincúlate con alguien para ver el álbum', style: TextStyle(color: Colors.grey)));
    
    String coupleDocId = _isUser1 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
    String user1Name = _isUser1 ? _myName : _partnerName;
    String user2Name = _isUser1 ? _partnerName : _myName;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('memories').where('coupleDocId', isEqualTo: coupleDocId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Aún no tienen aventuras juntos', style: TextStyle(color: Colors.grey)));
        
        List<AlbumMemory> memories = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          List<String> reviews = [];
          List<String> photos = [];
          if (data['user1_review'] != null && data['user1_review'].toString().isNotEmpty) reviews.add('$user1Name: ${data['user1_review']}');
          if (data['user2_review'] != null && data['user2_review'].toString().isNotEmpty) reviews.add('$user2Name: ${data['user2_review']}');
          photos.addAll(List<String>.from(data['user1_photos'] ?? []));
          photos.addAll(List<String>.from(data['user2_photos'] ?? []));
          return AlbumMemory(
            type: 'Pareja', title: data['adventure_title'] ?? 'Cita', emoji: '❤️',
            date: AlbumService.parseDate(data['timestamp']),
            reviews: reviews, photoUrls: photos,
          );
        }).toList();

        memories.sort((a, b) => b.date.compareTo(a.date));
        
        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: memories.length,
          itemBuilder: (context, index) => MemoryCard(memory: memories[index]),
        );
      },
    );
  }
}

class _GroupAlbumList extends StatefulWidget {
  const _GroupAlbumList();

  @override
  State<_GroupAlbumList> createState() => _GroupAlbumListState();
}

class _GroupAlbumListState extends State<_GroupAlbumList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('group_memories').where('members', arrayContains: myUid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Aún no hay expediciones grupales', style: TextStyle(color: Colors.grey)));
        
        List<AlbumMemory> memories = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return AlbumMemory(
            type: 'Grupo', title: data['adventure_title'] ?? 'Expedición', emoji: '👥',
            date: AlbumService.parseDate(data['timestamp']),
            reviews: [],
            photoUrls: List<String>.from((data['photos'] as Map?)?.values ?? []),
          );
        }).toList();

        memories.sort((a, b) => b.date.compareTo(a.date));
        
        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: memories.length,
          itemBuilder: (context, index) => MemoryCard(memory: memories[index]),
        );
      },
    );
  }
}