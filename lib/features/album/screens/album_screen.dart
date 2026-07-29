import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/album_memory.dart';
import '../providers/album_provider.dart';
import '../widgets/memory_card.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: customTheme.bg,
        appBar: AppBar(
          title: Text(
            'Álbum de Recuerdos',
            style: TextStyle(
              color: customTheme.text,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          backgroundColor: customTheme.elevatedSurface,
          centerTitle: true,
          elevation: 0,
          iconTheme: IconThemeData(color: customTheme.text),
          bottom: TabBar(
            labelColor: customTheme.primary,
            unselectedLabelColor: customTheme.muted,
            indicatorColor: customTheme.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
            isScrollable: false,
            tabs: const [
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
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    final provider = context.watch<AlbumProvider>();

    return StreamBuilder<List<AlbumMemory>>(
      stream: provider.allStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: customTheme.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SelectableText(
                'Error al cargar recuerdos:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.auto_stories,
            message:
                'Aún no tienes recuerdos guardados.\n¡Completa una aventura!',
          );
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

class _SoloAlbumList extends StatelessWidget {
  const _SoloAlbumList();

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    final provider = context.watch<AlbumProvider>();

    return StreamBuilder<List<AlbumMemory>>(
      stream: provider.soloStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: customTheme.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SelectableText(
                'Error al cargar aventuras solitarias:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.backpack_outlined,
            message:
                'Aún no tienes aventuras solitarias.\n¡Explora por tu cuenta!',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) =>
              MemoryCard(memory: snapshot.data![index]),
        );
      },
    );
  }
}

class _CoupleAlbumList extends StatelessWidget {
  const _CoupleAlbumList();

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    final provider = context.watch<AlbumProvider>();

    if (provider.partnerId == null) {
      return const EmptyStateWidget(
        icon: Icons.favorite_border,
        message: 'Vincúlate con alguien para ver el álbum de pareja.',
      );
    }

    return StreamBuilder<List<AlbumMemory>>(
      stream: provider.coupleStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: customTheme.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SelectableText(
                'Error al cargar recuerdos de pareja:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.favorite_outline,
            message: 'Aún no tienen aventuras juntos.\n¡Planeen una cita!',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) =>
              MemoryCard(memory: snapshot.data![index]),
        );
      },
    );
  }
}

class _GroupAlbumList extends StatelessWidget {
  const _GroupAlbumList();

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    final provider = context.watch<AlbumProvider>();

    return StreamBuilder<List<AlbumMemory>>(
      stream: provider.groupStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: customTheme.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SelectableText(
                'Error al cargar expediciones grupales:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.groups_outlined,
            message: 'Aún no hay expediciones grupales.\n¡Arma un grupo!',
          );
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