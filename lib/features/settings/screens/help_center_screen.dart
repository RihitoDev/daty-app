import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/theme_provider.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _searchQuery = '';

  static const String whatsappSupportUrl =
      'https://wa.me/59168476178?text=Hola%20equipo%20de%20Daty,%20necesito%20soporte%20personalizado.';

  final List<_FaqCategory> _faqCategories = [
    _FaqCategory(
      title: 'Vínculos y Pareja',
      icon: Icons.favorite_rounded,
      items: [
        _FaqItem(
          question: '¿Qué pasa si me desvinculo de mi pareja?',
          answer:
              'Entrarán en un periodo de recuperación de 3 días donde podrán retomar su vínculo. Además, sus recuerdos compartidos se resguardarán en una sección temporal por 7 días.',
        ),
        _FaqItem(
          question: '¿Cómo envío un código de vinculación?',
          answer:
              'Ve a la pantalla principal, presiona "Vincularme con alguien" y comparte el código de 6 caracteres generado.',
        ),
        _FaqItem(
          question: '¿Puedo cancelar una solicitud de vinculación?',
          answer:
              'Sí, si la otra persona aún no firma el pacto, puedes cancelar la invitación o rechazarla sin afectar tus recuerdos anteriores.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Álbum y Recuerdos',
      icon: Icons.photo_library_rounded,
      items: [
        _FaqItem(
          question: '¿Puedo mover recuerdos de Pareja a Mi Álbum Personal?',
          answer:
              'Sí, dentro del acordeón de resguardo o del álbum de pareja puedes presionar la opción de mover tus fotos a tu álbum Personal para conservarlas para siempre solo para ti.',
        ),
        _FaqItem(
          question: '¿Por qué no veo mis fotos de resguardo?',
          answer:
              'Asegúrate de estar en la pestaña "PAREJA" de tu Álbum de Recuerdos. Ahí aparecerá el acordeón desplegable con el contador de tiempo restante.',
        ),
        _FaqItem(
          question: '¿Qué sucede cuando vence el temporizador de 7 días?',
          answer:
              'Si no mueves los recuerdos a tu álbum Personal ni se reanuda el vínculo antes de que termine el plazo de 7 días, los recuerdos temporales se eliminarán automáticamente.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Cuenta y Seguridad',
      icon: Icons.shield_outlined,
      items: [
        _FaqItem(
          question: '¿Cómo cambio mi contraseña o correo?',
          answer:
              'Ve a Ajustes > Cuenta > Seguridad para gestionar tus credenciales y sesiones activas.',
        ),
        _FaqItem(
          question: '¿Cómo elimino mi cuenta permanentemente?',
          answer:
              'Puedes hacerlo desde Ajustes > Zona de peligro > Eliminar cuenta. Esta acción eliminará permanentemente toda tu información y no se podrá deshacer.',
        ),
      ],
    ),
  ];

  Future<void> _openWhatsAppSupport() async {
    try {
      final Uri uri = Uri.parse(whatsappSupportUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;

    final filteredCategories = _faqCategories.map((category) {
      final matchingItems = category.items.where((item) {
        final q = item.question.toLowerCase();
        final a = item.answer.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return q.contains(query) || a.contains(query);
      }).toList();

      return _FaqCategory(
        title: category.title,
        icon: category.icon,
        items: matchingItems,
      );
    }).where((cat) => cat.items.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Centro de Ayuda',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.text),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Buscador
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(color: colors.text),
            decoration: InputDecoration(
              hintText: 'Buscar duda o problema...',
              hintStyle: TextStyle(color: colors.text2),
              prefixIcon: Icon(Icons.search, color: colors.muted),
              filled: true,
              fillColor: colors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (filteredCategories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No se encontraron preguntas relativas a "$_searchQuery"',
                  style: TextStyle(color: colors.text2),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...filteredCategories.map((cat) => _buildCategoryCard(cat, colors)),

          const SizedBox(height: 12),
          // Tarjeta de soporte directo integrada al tema
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.support_agent_rounded,
                        color: colors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Necesitas soporte personal?',
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Atención y ayuda directa por WhatsApp',
                            style: TextStyle(
                              color: colors.text2,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openWhatsAppSupport,
                    icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                    label: const Text(
                      'Contactar a Soporte por WhatsApp',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(_FaqCategory cat, dynamic colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(cat.icon, color: colors.primary),
          title: Text(
            cat.title,
            style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
          ),
          iconColor: colors.primary,
          collapsedIconColor: colors.muted,
          children: cat.items.map((item) => _buildFaqItem(item, colors)).toList(),
        ),
      ),
    );
  }

  Widget _buildFaqItem(_FaqItem item, dynamic colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.bg, width: 2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Text(
            item.question,
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              item.answer,
              style: TextStyle(color: colors.text2, fontSize: 13, height: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqCategory {
  final String title;
  final IconData icon;
  final List<_FaqItem> items;
  _FaqCategory({required this.title, required this.icon, required this.items});
}

class _FaqItem {
  final String question;
  final String answer;
  _FaqItem({required this.question, required this.answer});
}
