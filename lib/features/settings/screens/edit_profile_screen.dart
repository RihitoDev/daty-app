import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/username_rules.dart';
import '../../profile/providers/profile_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late Future<UsernameChangeStatus> _changeStatus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>();
    _nameController = TextEditingController(text: profile.userName);
    _changeStatus = profile.getUsernameChangeStatus();
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
          FutureBuilder<UsernameChangeStatus>(
            future: _changeStatus,
            builder: (context, snapshot) {
              final status = snapshot.data;
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              final canChange = status?.enabled == true;
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nombre en Daty',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      readOnly: !canChange,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          UsernameRules.maxLength,
                        ),
                      ],
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        suffixIcon: loading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                canChange
                                    ? Icons.celebration_outlined
                                    : Icons.lock_outline_rounded,
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      canChange
                          ? 'Evento activo: tienes ${status?.remainingChanges ?? 0} cambio disponible.'
                          : status?.eventActive == true
                              ? 'Ya utilizaste el cambio disponible de este evento.'
                              : 'El nombre solo puede modificarse durante eventos especiales.',
                      style: TextStyle(
                        color: canChange ? colors.primary : colors.text2,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight:
                            canChange ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    if (canChange) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
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
                          label: const Text('Guardar nuevo nombre'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
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
        ],
      ),
    );
  }

  Future<void> _save() async {
    final validation = UsernameRules.validationMessage(_nameController.text);
    if (validation != null) {
      CustomSnackBar.showError(context, validation);
      return;
    }
    setState(() => _saving = true);
    final error = await context
        .read<ProfileProvider>()
        .updateUserName(_nameController.text);
    if (!mounted) return;
    setState(() => _saving = false);

    if (error == null) {
      CustomSnackBar.showSuccess(context, 'Nombre actualizado');
      setState(() {
        _changeStatus =
            context.read<ProfileProvider>().getUsernameChangeStatus();
      });
    } else if (error == 'username-taken') {
      CustomSnackBar.showError(context, 'Ese nombre ya está en uso');
    } else if (error == 'event-limit-reached' || error == 'event-inactive') {
      CustomSnackBar.showError(context, 'El evento ya no está disponible');
    } else {
      CustomSnackBar.showError(context, 'No se pudo actualizar el nombre');
    }
  }
}
