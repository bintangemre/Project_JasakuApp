import 'package:flutter/material.dart';

/// This page is intentionally minimal.
/// Pricing types management is handled via the admin web panel at /admin/
/// which provides full CRUD for pricing units, contract types, and service mappings.
///
/// This screen exists only as a placeholder in the Flutter admin hub.
class AdminPricingTypesPage extends StatelessWidget {
  const AdminPricingTypesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Kelola Harga'),
        backgroundColor: const Color(0xFF00A651),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A651).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.attach_money,
                  size: 48,
                  color: Color(0xFF00A651),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Kelola melalui Admin Web',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola satuan harga, tipe kontrak, dan mapping layanan\nmelalui dashboard admin web.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '/admin/',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
