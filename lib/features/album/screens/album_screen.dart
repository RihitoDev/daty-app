import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/album_provider.dart';
import '../models/album_memory.dart';
import '../widgets/memory_card.dart';
import '../../shared/widgets/empty_state_widget.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlbumProvider>().fetchAllMemories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            'Álbum de Recuerdos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          ),
          backgroundColor: const Color(0xFF9C27B0),
          centerTitle: true,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amberAccent,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
            isScrollable: false,
            tabs: [
              Tab(text: 'TODOS', icon: Icon(Icons.auto_stories, size: 18)),
              Tab(text: 'SOLO', icon: Icon(Icons.backpack_outlined, size: 18)),
              Tab(text: 'PAREJA', icon: Icon(Icons.favorite_outline, size: 18)),
              Tab(text: 'GRUPO', icon: Icon(Icons.groups_outlined, size: 18)),
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

class _AllAlbumList extends StatelessWidget {
  const _AllAlbumList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlbumProvider>();

    if (provider.isLoadingAll) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0)));
    }

    if (provider.allMemories.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.auto_stories,
        message: 'Aún no tienes recuerdos guardados.\n¡Completa una aventura!',
        onRetry: () => provider.fetchAllMemories(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchAllMemories(),
      color: const Color(0xFF9C27B0),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        itemCount: provider.allMemories.length,
        itemBuilder: (context, index) => MemoryCard(memory: provider.allMemories[index]),
      ),
    );
  }
}

class _SoloAlbumList extends StatelessWidget {
  const _SoloAlbumList();

  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN: Cambiado de read() a watch()
    final provider = context.watch<AlbumProvider>();

    return StreamBuilder<List<AlbumMemory>>(
      stream: provider.soloStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateWidget(icon: Icons.backpack_outlined, message: 'Aún no tienes aventuras solitarias.\n¡Explora por tu cuenta!');
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) => MemoryCard(memory: snapshot.data![index]),
        );
      },
    );
  }
}

class _CoupleAlbumList extends StatelessWidget {
  const _CoupleAlbumList();

  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN: Cambiado de read() a watch()
    final provider = context.watch<AlbumProvider>();

    if (provider.partnerId == null) {
      return const EmptyStateWidget(icon: Icons.favorite_border, message: 'Vincúlate con alguien para ver el álbum de pareja.');
    }

    return StreamBuilder<List<AlbumMemory>>(
      stream: provider.coupleStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateWidget(icon: Icons.favorite_outline, message: 'Aún no tienen aventuras juntos.\n¡Planeen una cita!');
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) => MemoryCard(memory: snapshot.data![index]),
        );
      },
    );
  }
}

class _GroupAlbumList extends StatelessWidget {
  const _GroupAlbumList();

  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN: Cambiado de read() a watch()
    final provider = context.watch<AlbumProvider>();

    return StreamBuilder<List<AlbumMemory>>(
      stream: provider.groupStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateWidget(icon: Icons.groups_outlined, message: 'Aún no hay expediciones grupales.\n¡Arma un grupo!');
        }
        final memories = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          itemCount: memories.length,
          itemBuilder: (context, index) => MemoryCard(memory: memories[index]),
        );
      },
    );
  }
}