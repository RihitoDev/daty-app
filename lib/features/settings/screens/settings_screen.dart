import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../../profile/screens/profile_screen.dart';
import '../../shared/widgets/custom_snackbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SettingsProvider(Provider.of<AuthProvider>(context, listen: false)),
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {

          final authProvider = Provider.of<AuthProvider>(context);
          final bool hasPartner = authProvider.userData != null && authProvider.userData!['partnerId'] != null;

          return Scaffold(
            backgroundColor: const Color(0xFFF1E5F5),
            appBar: AppBar(
              title: const Text('Ajustes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF9C27B0),
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Cuenta'),
                  _buildSettingsCard([
                    ListTile(
                      leading: const Icon(Icons.person_outline, color: Color(0xFF9C27B0)),
                      title: const Text('Mi Perfil'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                      },
                    ),
                  ]),
                  
                  if (hasPartner) ...[
                    const SizedBox(height: 25),
                    _buildSectionTitle('Pareja'),
                    _buildSettingsCard([
                      ListTile(
                        leading: const Icon(Icons.link_off, color: Colors.redAccent),
                        title: const Text('Desvincular Pareja', style: TextStyle(color: Colors.redAccent)),
                        subtitle: const Text('Se eliminará el progreso, mapa y recuerdos compartidos'),
                        trailing: settingsProvider.isProcessing 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: settingsProvider.isProcessing ? null : () => _showUnlinkConfirmation(context, settingsProvider),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 25),
                  _buildSectionTitle('Aventura en Solitario'),
                  _buildSettingsCard([
                    ListTile(
                      leading: const Icon(Icons.refresh, color: Color(0xFF1976D2)),
                      title: const Text('Reiniciar Progreso Solo', style: TextStyle(color: Color(0xFF1976D2))),
                      subtitle: const Text('Borra tu mapa y recuerdos individuales'),
                      trailing: settingsProvider.isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: settingsProvider.isProcessing ? null : () async {
                         final confirm = await showDialog<bool>(
                           context: context,
                           builder: (dialogContext) => AlertDialog(
                             title: const Text('¿Reiniciar progreso?'),
                             content: const Text('Se borrarán todas tus aventuras y fotos en solitario. Esta acción no se puede deshacer.'),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                               ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Borrar')),
                             ],
                           )
                         );
                         if (confirm == true) {
                           final error = await settingsProvider.resetSoloProgress();
                           if (context.mounted) {
                             if (error != null) {
                               CustomSnackBar.showError(context, error);
                             } else {
                               CustomSnackBar.showSuccess(context, 'Progreso reiniciado');
                             }
                           }
                         }
                      },
                    ),
                  ]),

                  const SizedBox(height: 25),

                  _buildSectionTitle('Sesión'),
                  _buildSettingsCard([
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.black54),
                      title: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _showLogoutConfirmation(context),
                    ),
                  ]),

                  const SizedBox(height: 50),
                  
                  const Center(
                    child: Text('Daty v1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9C27B0))),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres salir de tu cuenta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: () {
              Navigator.pop(dialogContext);
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUnlinkConfirmation(BuildContext context, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('💔 Romper Vínculo', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Esta acción es irreversible. Se eliminará todo el progreso de su mapa de pareja y recuerdos compartidos. ¿Están seguros?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final error = await provider.unlinkPartner();
              
              if (context.mounted) {
                if (error != null) {
                  CustomSnackBar.showError(context, error);
                } else {
                  CustomSnackBar.showSuccess(context, 'Se ha roto el vínculo exitosamente');
                }
              }
            },
            child: const Text('Desvincular', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}