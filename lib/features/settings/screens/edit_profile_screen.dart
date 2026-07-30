import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<ProfileProvider>().userName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    final profile = context.watch<ProfileProvider>();
    final auth = context.watch<AuthProvider>();
    ImageProvider? avatarImage;
    if (profile.selectedImageBytes != null) {
      avatarImage = MemoryImage(profile.selectedImageBytes!);
    } else if (profile.photoUrl != null) {
      avatarImage = CachedNetworkImageProvider(profile.photoUrl!);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('Editar perfil', style: TextStyle(color: colors.text)),
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: colors.primaryLight,
                  backgroundImage: avatarImage,
                  child: profile.photoUrl == null &&
                          profile.selectedImageBytes == null
                      ? Text(
                          profile.initials,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    onPressed: profile.isUploadingPhoto
                        ? null
                        : profile.pickAndUploadImage,
                    icon: profile.isUploadingPhoto
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: auth.user?.email ?? '',
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.email_outlined),
              helperText: 'El correo no se puede cambiar desde aquí.',
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
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
    setState(() => _saving = true);
    final error = await context
        .read<ProfileProvider>()
        .updateUserName(_nameController.text);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (error) {
      case null:
        CustomSnackBar.showSuccess(context, 'Perfil actualizado');
        Navigator.pop(context);
      case 'invalid-name':
        CustomSnackBar.showError(
            context, 'El nombre debe tener entre 2 y 40 caracteres');
      case 'username-taken':
        CustomSnackBar.showError(context, 'Ese nombre ya está en uso');
      default:
        CustomSnackBar.showError(context, 'No se pudo actualizar el perfil');
    }
  }
}
