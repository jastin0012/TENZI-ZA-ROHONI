import 'package:flutter/material.dart';
// google_mobile_ads not required here
// ad_service not required in this file; banners use BannerAdWidget
import 'package:tenzi_za_rohoni/theme/colors.dart';
// Banner handled globally in MainLayout
import 'package:url_launcher/url_launcher.dart';

/// Clean, single-file Feedback screen. Uses centralized AdService and BannerAdWidget.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;
  // No local ad service field needed — banners are displayed only.

  static const String _targetEmail = 'jastinsalvatory10@gmail.com';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[<>]'), '').trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    FocusScope.of(context).unfocus();
    final name = _sanitize(_nameController.text);
    final email = _sanitize(_emailController.text);
    final message = _sanitize(_messageController.text);
    try {
      // Do not show interstitials on feedback submit. Keep banners only.
      // Prefer opening the user's mail app with a prefilled mailto link so
      // the user can send the message from their preferred mail client.
      final mail = Uri(
        scheme: 'mailto',
        path: _targetEmail,
        queryParameters: {
          'subject': 'Maoni',
          'body': 'Name: $name\nEmail: $email\n\n$message',
        },
      );
      final ok = await launchUrl(mail, mode: LaunchMode.externalApplication);
      if (ok) {
        _nameController.clear();
        _emailController.clear();
        _messageController.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asante, maoni yametumwa')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imeshindikana kufungua programu ya barua pepe'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Scaffold(
      backgroundColor:
          isLight ? AppColors.primary : theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Maoni'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Ingiza jina',
                            hintStyle: TextStyle(
                                color: theme.hintColor.withOpacity(0.8)),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 12.0),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                  color: theme.dividerColor
                                      .withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  BorderSide(color: theme.colorScheme.primary),
                            ),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Tafadhali weka jina'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        // Email
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            hintText: 'Barua pepe',
                            hintStyle: TextStyle(
                                color:
                                    theme.hintColor.withOpacity(0.8)),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 12.0),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                  color: theme.dividerColor
                                      .withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  BorderSide(color: theme.colorScheme.primary),
                            ),
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Tafadhali weka barua pepe';
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(s)) {
                              return 'Email sio sahihi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Message
                        TextFormField(
                          controller: _messageController,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText: 'Maoni yako',
                            hintStyle: TextStyle(
                                color:
                                    theme.hintColor.withOpacity(0.8)),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 12.0),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                  color: theme.dividerColor
                                      .withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  BorderSide(color: theme.colorScheme.primary),
                            ),
                          ),
                          validator: (v) => (v ?? '').trim().length < 5
                              ? 'Andika maoni (angalau herufi 5)'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _sending ? null : _submit,
                            child: Text(_sending ? 'Inatuma...' : 'Tuma'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      // Banner handled globally in MainLayout; removed per-screen banner.
      bottomNavigationBar: null,
    );
  }
}
