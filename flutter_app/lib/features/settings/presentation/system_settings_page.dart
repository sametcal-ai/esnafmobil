import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/config/app_settings.dart';

class SystemSettingsPage extends ConsumerWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return AppScaffold(
      title: 'Sistem Ayarları',
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
                            value: settings.barcodeScanDelaySeconds
                                .clamp(0.5, 10.0),
                            min: 0.5,
                            max: 10.0,
                            divisions: 95,
                            label:
                                '${settings.barcodeScanDelaySeconds.toStringAsFixed(1)} sn',
                            onChanged: (value) {
                              controller.setBarcodeDelaySeconds(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${settings.barcodeScanDelaySeconds.toStringAsFixed(1)} sn',
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
                            value: settings.defaultMarginPercent
                                .clamp(0, 100.0),
                            min: 0,
                            max: 100.0,
                            divisions: 100,
                            label:
                                '%${settings.defaultMarginPercent.toStringAsFixed(0)}',
                            onChanged: (value) {
                              controller.setDefaultMarginPercent(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '%${settings.defaultMarginPercent.toStringAsFixed(0)}',
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
                            value: settings.searchFilterMinChars.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: settings.searchFilterMinChars.toString(),
                            onChanged: (value) {
                              controller.setSearchFilterMinChars(
                                value.round(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            settings.searchFilterMinChars.toString(),
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
                            value: settings.movementsPageSize
                                .clamp(5, 100)
                                .toDouble(),
                            min: 5,
                            max: 100,
                            divisions: 19, // 5,10,...,100 => 20 değer, 19 aralık
                            label: settings.movementsPageSize.toString(),
                            onChanged: (value) {
                              controller.setMovementsPageSize(value.round());
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            settings.movementsPageSize.toString(),
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