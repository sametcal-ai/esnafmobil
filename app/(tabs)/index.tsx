import { Image } from 'expo-image';
import React, { useMemo } from 'react';
import { FlatList, Platform, StyleSheet, View } from 'react-native';

import { HelloWave } from '@/components/HelloWave';
import ParallaxScrollView from '@/components/ParallaxScrollView';
import { ThemedText } from '@/components/ThemedText';
import { ThemedView } from '@/components/ThemedView';
import type { DashboardMetrics, ProductSalesSummary } from '@/domain/reports';
import type { StockSnapshot } from '@/domain/inventory';

/**
 * In a real app these would come from your offline data store + sync layer.
 * For now, some hard-coded example data is used to demonstrate the dashboard UI.
 */
const mockDashboard: DashboardMetrics = {
  totalRevenue: 12345.67,
  totalProfit: 4321.09,
  bestSellingProducts: [
    { productId: 'coffee-1', quantitySold: 150, revenue: 2250, cost: 1200, profit: 1050 },
    { productId: 'tea-1', quantitySold: 90, revenue: 900, cost: 450, profit: 450 },
    { productId: 'snack-1', quantitySold: 60, revenue: 600, cost: 300, profit: 300 },
  ],
  lowStockProducts: [
    { productId: 'sugar-1', quantityOnHand: 3, averageUnitCost: 2.5, lastUpdated: new Date() },
    { productId: 'milk-1', quantityOnHand: 5, averageUnitCost: 1.2, lastUpdated: new Date() },
  ],
};

export default function HomeScreen() {
  const metrics = mockDashboard;

  const bestSellers = useMemo(
    () => metrics.bestSellingProducts.slice(0, 5),
    [metrics.bestSellingProducts]
  );

  return (
    <ParallaxScrollView
      headerBackgroundColor={{ light: '#A1CEDC', dark: '#1D3D47' }}
      headerImage={
        <Image
          source={require('@/assets/images/partial-react-logo.png')}
          style={styles.reactLogo}
        />
      }>
      <ThemedView style={styles.titleContainer}>
        <ThemedText type="title">Dashboard</ThemedText>
        <HelloWave />
      </ThemedView>

      {/* Top-level KPIs */}
      <ThemedView style={styles.kpiRow}>
        <KpiCard label="Total Sales" value={metrics.totalRevenue} />
        <KpiCard label="Total Profit" value={metrics.totalProfit} />
      </ThemedView>

      {/* Best-selling products */}
      <ThemedView style={styles.section}>
        <ThemedText type="subtitle">Best-selling products</ThemedText>
        <FlatList
          data={bestSellers}
          keyExtractor={(item) => item.productId}
          scrollEnabled={false}
          renderItem={({ item }) => <BestSellerRow product={item} />}
          ItemSeparatorComponent={() => <View style={styles.separator} />}
        />
      </ThemedView>

      {/* Low stock alerts */}
      <ThemedView style={styles.section}>
        <ThemedText type="subtitle">Low stock alerts</ThemedText>
        {metrics.lowStockProducts.length === 0 ? (
          <ThemedText>No products are low on stock.</ThemedText>
        ) : (
          metrics.lowStockProducts.map((snapshot) => (
            <LowStockRow key={snapshot.productId} snapshot={snapshot} />
          ))
        )}
      </ThemedView>
    </ParallaxScrollView>
  );
}

function KpiCard({ label, value }: { label: string; value: number }) {
  return (
    <View style={styles.kpiCard}>
      <ThemedText type="subtitle">{label}</ThemedText>
      <ThemedText type="title">{value.toFixed(2)}</ThemedText>
    </View>
  );
}

function BestSellerRow({ product }: { product: ProductSalesSummary }) {
  return (
    <View style={styles.row}>
      <View style={{ flex: 1 }}>
        <ThemedText type="defaultSemiBold">{product.productId}</ThemedText>
        <ThemedText>{product.quantitySold} units sold</ThemedText>
      </View>
      <View style={{ alignItems: 'flex-end' }}>
        <ThemedText type="defaultSemiBold">
          {product.revenue.toFixed(2)}
        </ThemedText>
        <ThemedText>Profit {product.profit.toFixed(2)}</ThemedText>
      </View>
    </View>
  );
}

function LowStockRow({ snapshot }: { snapshot: StockSnapshot }) {
  return (
    <View style={styles.row}>
      <ThemedText type="defaultSemiBold" style={{ flex: 1 }}>
        {snapshot.productId}
      </ThemedText>
      <ThemedText>Qty: {snapshot.quantityOnHand}</ThemedText>
    </View>
  );
}

const styles = StyleSheet.create({
  titleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  kpiRow: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 16,
  },
  kpiCard: {
    flex: 1,
    padding: 12,
    borderRadius: 8,
  },
  section: {
    marginTop: 24,
    gap: 8,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  separator: {
    height: 8,
  },
  reactLogo: {
    height: 178,
    width: 290,
    bottom: 0,
    left: 0,
    position: 'absolute',
  },
});
