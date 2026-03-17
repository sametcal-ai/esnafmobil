import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/config/app_settings.dart';

import '../../auth/domain/current_user_provider.dart';
import '../../auth/domain/user.dart';

class SystemSettingsPage extends ConsumerStatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  ConsumerState<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends ConsumerState<SystemSettingsPage> {
  AppSettings? _draft;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      final settings = ref.read(appSettingsProvider);
      setState(() {
        _draft = settings;
      });
    });
  }

  void _syncFrom(AppSettings settings) {
    if (_dirty) return;
    _draft = settings;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final user = ref.watch(currentUserProvider);
    final isAdmin = user != null && user.role == UserRole.admin;

    _draft ??= settings;
    _syncFrom(settings);

    final draft = _draft ?? settings;

    Future<void> onSave() async {
      await controller.save(draft);
      if (mounted) {
        setState(() {
          _dirty = false;
        });
      }
    }

    return AppScaffold(
      title: 'Sistem Ayarları',
      actions: [
        if (isAdmin)
          TextButton(
            onPressed: _dirty ? onSave : null,
            child: const Text('Kaydet'),
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Barkod Okuma Gecikmesi',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aynı barkodun tekrar sayılması için minimum süre. '
                      '0.5 - 10 saniye arasında ayarlayabilirsiniz.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: draft.barcodeScanDelaySeconds
                                .clamp(0.5, 10.0),
                            min: 0.5,
                            max: 10.0,
                            divisions: 95,
                            label:
                                '${draft.barcodeScanDelaySeconds.toStringAsFixed(1)} sn',
                            onChanged: isAdmin
                                ? (value) {
                                    setState(() {
                                      _dirty = true;
                                      _draft = draft.copyWith(
                                        barcodeScanDelaySeconds: value,
                                      );
                                    });
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${draft.barcodeScanDelaySeconds.toStringAsFixed(1)} sn',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Varsayılan Kâr Marjı (%)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ürün alış işlemlerinde ve fiyat listelerinde '
                      'otomatik kullanılacak varsayılan kâr oranı.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: draft.defaultMarginPercent
                                .clamp(0, 100.0),
                            min: 0,
                            max: 100.0,
                            divisions: 100,
                            label:
                                '%${draft.defaultMarginPercent.toStringAsFixed(0)}',
                            onChanged: isAdmin
                                ? (value) {
                                    setState(() {
                                      _dirty = true;
                                      _draft = draft.copyWith(
                                        defaultMarginPercent: value,
                                      );
                                    });
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '%${draft.defaultMarginPercent.toStringAsFixed(0)}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Arama Filtreleme Eşiği',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Arama kaç karakterden sonra aktif olsun',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: draft.searchFilterMinChars.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: draft.searchFilterMinChars.toString(),
                            onChanged: isAdmin
                                ? (value) {
                                    setState(() {
                                      _dirty = true;
                                      _draft = draft.copyWith(
                                        searchFilterMinChars: value.round(),
                                      );
                                    });
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            draft.searchFilterMinChars.toString(),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hareket Listesi Kayıt Sayısı',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Müşteri ve ürün detay sayfalarındaki hareket listelerinde '
                      'gösterilecek maksimum kayıt sayısı.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: draft.movementsPageSize
                                .clamp(5, 100)
                                .toDouble(),
                            min: 5,
                            max: 100,
                            divisions: 19, // 5,10,...,100 => 20 değer, 19 aralık
                            label: draft.movementsPageSize.toString(),
                            onChanged: isAdmin
                                ? (value) {
                                    setState(() {
                                      _dirty = true;
                                      _draft = draft.copyWith(
                                        movementsPageSize: value.round(),
                                      );
                                    });
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            draft.movementsPageSize.toString(),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}