import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _statusController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>();
    _nameController = TextEditingController(text: profile.userName);
    _statusController = TextEditingController(text: profile.statusMessage);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    final profile = context.watch<ProfileProvider>();
    final auth = context.watch<AuthProvider>();
    ImageProvider? avatar;
    if (profile.selectedImageBytes != null) {
      avatar = MemoryImage(profile.selectedImageBytes!);
    } else if (profile.photoUrl != null) {
      avatar = CachedNetworkImageProvider(profile.photoUrl!);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('Perfil', style: TextStyle(color: colors.text)),
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.accent],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 62,
                    backgroundColor: colors.primaryLight,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? Text(
                            profile.initials,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 31,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: profile.isUploadingPhoto
                      ? null
                      : () => profile.pickAndUploadImage(context),
                  icon: profile.isUploadingPhoto
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    profile.isUploadingPhoto ? 'Subiendo...' : 'Cambiar foto',
                  ),
                ),
                const SizedBox(height: 7),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nombre de usuario',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 40,
                  style: TextStyle(color: colors.text),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    hintText: 'Tu nombre en Daty',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado personal',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _statusController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 60,
                  style: TextStyle(color: colors.text),
                  decoration: const InputDecoration(
                    hintText: 'Ej: Coleccionando momentos especiales...',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Icon(Icons.email_outlined, color: colors.primary),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Correo de la cuenta',
                        style: TextStyle(color: colors.text2, fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        auth.user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  auth.user?.emailVerified == true
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  color: auth.user?.emailVerified == true
                      ? Colors.green
                      : colors.muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final nameText = _nameController.text.trim();
    if (nameText.length < 2 || nameText.length > 40) {
      CustomSnackBar.showError(
        context,
        'El nombre debe tener entre 2 y 40 caracteres',
      );
      return;
    }
    setState(() => _saving = true);
    final profileProvider = context.read<ProfileProvider>();

    await profileProvider.updateStatusMessage(_statusController.text);
    final error = await profileProvider.updateUserName(nameText);

    if (!mounted) return;
    setState(() => _saving = false);

    if (error == null) {
      CustomSnackBar.showSuccess(context, 'Perfil actualizado');
      Navigator.pop(context);
    } else if (error == 'username-taken') {
      CustomSnackBar.showError(context, 'Ese nombre ya está en uso');
    } else {
      CustomSnackBar.showError(context, 'No se pudo actualizar el nombre');
    }
  }
}