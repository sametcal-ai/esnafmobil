import React, { useMemo, useState } from 'react';
import { FlatList, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/ThemedText';
import { ThemedView } from '@/components/ThemedView';
import {
  buildDailySalesReport,
  buildMonthlySalesReport,
  buildProductSalesReport,
  buildProfitSummary,
  type DailySalesBucket,
  type ProductSalesSummary,
  type ProfitSummary,
  type SaleRecord,
} from '@/domain/reports';

/**
 * Placeholder data – replace with real sales data from your local store.
 */
const mockSales: SaleRecord[] = [
  {
    id: 's1',
    timestamp: '2026-01-01T10:15:00Z',
    lines: [
      { productId: 'coffee-1', quantity: 2, unitPrice: 15, unitCost: 8 },
      { productId: 'tea-1', quantity: 1, unitPrice: 10, unitCost: 5 },
    ],
  },
  {
    id: 's2',
    timestamp: '2026-01-01T14:30:00Z',
    lines: [{ productId: 'snack-1', quantity: 3, unitPrice: 5, unitCost: 2 }],
  },
  {
    id: 's3',
    timestamp: '2026-01-02T09:00:00Z',
    lines: [{ productId: 'coffee-1', quantity: 1, unitPrice: 15, unitCost: 8 }],
  },
];

type ReportTab = 'daily' | 'monthly' | 'products' | 'summary';

export default function ReportsScreen() {
  const [activeTab, setActiveTab] = useState<ReportTab>('daily');

  const daily = useMemo(() => buildDailySalesReport(mockSales), []);
  const monthly = useMemo<ProfitSummary>(
    () => buildMonthlySalesReport(mockSales, '2026-01'),
    []
  );
  const product = useMemo<ProductSalesSummary[]>(
    () => buildProductSalesReport(mockSales),
    []
  );
  const summary = useMemo<ProfitSummary>(() => buildProfitSummary(mockSales), []);

  return (
    <ThemedView style={styles.container}>
      <ThemedText type="title" style={styles.title}>
        Reports
      </ThemedText>

      {/* Simple tab-like toggles */}
      <View style={styles.tabRow}>
        <ReportTabButton label="Daily" active={activeTab === 'daily'} onPress={() => setActiveTab('daily')} />
        <ReportTabButton label="Monthly" active={activeTab === 'monthly'} onPress={() => setActiveTab('monthly')} />
        <ReportTabButton label="Products" active={activeTab === 'products'} onPress={() => setActiveTab('products')} />
        <ReportTabButton label="Summary" active={activeTab === 'summary'} onPress={() => setActiveTab('summary')} />
      </View>

      <View style={styles.content}>
        {activeTab === 'daily' && <DailyReportView buckets={daily} />}
        {activeTab === 'monthly' && <MonthlyReportView summary={monthly} />}
        {activeTab === 'products' && <ProductReportView products={product} />}
        {activeTab === 'summary' && <SummaryReportView summary={summary} />}
      </View>
    </ThemedView>
  );
}

function ReportTabButton({
  label,
  active,
  onPress,
}: {
  label: string;
  active: boolean;
  onPress: () => void;
}) {
  return (
    <ThemedText
      onPress={onPress}
      style={[styles.tab, active && styles.tabActive]}
      type={active ? 'defaultSemiBold' : 'default'}>
      {label}
    </ThemedText>
  );
}

function DailyReportView({ buckets }: { buckets: DailySalesBucket[] }) {
  if (buckets.length === 0) {
    return <ThemedText>No sales recorded yet.</ThemedText>;
  }

  return (
    <FlatList
      data={buckets}
      keyExtractor={(item) => item.date}
      renderItem={({ item }) => (
        <View style={styles.row}>
          <ThemedText style={{ flex: 1 }}>{item.date}</ThemedText>
          <ThemedText>Sales: {item.revenue.toFixed(2)}</ThemedText>
          <ThemedText>Profit: {item.profit.toFixed(2)}</ThemedText>
        </View>
      )}
      ItemSeparatorComponent={() => <View style={styles.separator} />}
    />
  );
}

function MonthlyReportView({ summary }: { summary: ProfitSummary }) {
  return (
    <View style={styles.block}>
      <ThemedText>Total revenue: {summary.totalRevenue.toFixed(2)}</ThemedText>
      <ThemedText>Total cost: {summary.totalCost.toFixed(2)}</ThemedText>
      <ThemedText>Total profit: {summary.totalProfit.toFixed(2)}</ThemedText>
    </View>
  );
}

function ProductReportView({ products }: { products: ProductSalesSummary[] }) {
  if (products.length === 0) {
    return <ThemedText>No product sales yet.</ThemedText>;
  }

  return (
    <FlatList
      data={products}
      keyExtractor={(item) => item.productId}
      renderItem={({ item }) => (
        <View style={styles.row}>
          <View style={{ flex: 1 }}>
            <ThemedText type="defaultSemiBold">{item.productId}</ThemedText>
            <ThemedText>{item.quantitySold} units</ThemedText>
          </View>
          <View style={{ alignItems: 'flex-end' }}>
            <ThemedText>Sales {item.revenue.toFixed(2)}</ThemedText>
            <ThemedText>Profit {item.profit.toFixed(2)}</ThemedText>
          </View>
        </View>
      )}
      ItemSeparatorComponent={() => <View style={styles.separator} />}
    />
  );
}

function SummaryReportView({ summary }: { summary: ProfitSummary }) {
  return (
    <View style={styles.block}>
      <ThemedText type="subtitle">Profit and cost summary</ThemedText>
      <ThemedText>Total revenue: {summary.totalRevenue.toFixed(2)}</ThemedText>
      <ThemedText>Total cost: {summary.totalCost.toFixed(2)}</ThemedText>
      <ThemedText>Total profit: {summary.totalProfit.toFixed(2)}</ThemedText>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    gap: 16,
  },
  title: {
    marginBottom: 4,
  },
  tabRow: {
    flexDirection: 'row',
    gap: 12,
  },
  tab: {
    paddingVertical: 4,
    paddingHorizontal: 8,
    borderRadius: 8,
  },
  tabActive: {
    textDecorationLine: 'underline',
  },
  content: {
    flex: 1,
    marginTop: 8,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  separator: {
    height: 8,
  },
  block: {
    gap: 8,
  },
});