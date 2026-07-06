import 'package:flutter/material.dart';
import 'provider_faq_screen.dart';
import 'provider_terms_screen.dart';

class ProviderRegisterTermsScreen extends StatefulWidget {
  const ProviderRegisterTermsScreen({super.key});

  @override
  State<ProviderRegisterTermsScreen> createState() =>
      _ProviderRegisterTermsScreenState();
}

class _ProviderRegisterTermsScreenState
    extends State<ProviderRegisterTermsScreen> {
  bool _agreed = false;
  bool _faqOpened = false;
  bool _termsOpened = false;

  Future<void> _openFaq() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProviderFaqScreen()),
    );
    if (mounted) setState(() => _faqOpened = true);
  }

  Future<void> _openTerms() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProviderTermsScreen()),
    );
    if (mounted) setState(() => _termsOpened = true);
  }

  bool get _canAgree => _faqOpened && _termsOpened;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: cs.onSurface,
        title: const Text('Pendaftaran Mitra',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Syarat & Ketentuan',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Baca dan setujui syarat & ketentuan Jasaku sebelum melanjutkan.',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.help_outline,
                          color: _faqOpened ? cs.primary : cs.onSurfaceVariant),
                      title: Text('FAQ — Frequently Asked Questions',
                          style: TextStyle(
                              fontWeight:
                                  _faqOpened ? FontWeight.w600 : FontWeight.normal)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_faqOpened)
                            Icon(Icons.check_circle,
                                color: cs.primary, size: 20),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: _openFaq,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.description_outlined,
                          color: _termsOpened
                              ? cs.primary
                              : cs.onSurfaceVariant),
                      title: Text('Syarat & Ketentuan',
                          style: TextStyle(
                              fontWeight: _termsOpened
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_termsOpened)
                            Icon(Icons.check_circle,
                                color: cs.primary, size: 20),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: _openTerms,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (!_canAgree)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Baca FAQ dan Syarat & Ketentuan terlebih dahulu',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              const Spacer(),
              CheckboxListTile(
                value: _agreed,
                onChanged: _canAgree
                    ? (v) => setState(() => _agreed = v ?? false)
                    : null,
                title: Text(
                  'Saya telah membaca dan menyetujui FAQ dan Syarat & Ketentuan yang berlaku',
                  style: TextStyle(
                    fontSize: 13,
                    color: _canAgree ? null : cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: cs.primary,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (_agreed && _canAgree)
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text(
                    'Lanjut',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
