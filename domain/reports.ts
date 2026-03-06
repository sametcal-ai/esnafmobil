import type { StockSnapshot } from './inventory';

export interface SaleLine {
  productId: string;
  quantity: number;
  unitPrice: number;
  unitCost: number;
}

export interface SaleRecord {
  id: string;
  timestamp: string; // ISO date-time
  lines: SaleLine[];
}

/**
 * Summary of revenue, cost, and profit for a time period.
 */
export interface ProfitSummary {
  totalRevenue: number;
  totalCost: number;
  totalProfit: number;
}

export interface DailySalesBucket {
  date: string; // YYYY-MM-DD
  revenue: number;
  cost: number;
  profit: number;
}

export interface ProductSalesSummary {
  productId: string;
  quantitySold: number;
  revenue: number;
  cost: number;
  profit: number;
}

export interface DashboardMetrics {
  totalRevenue: number;
  totalProfit: number;
  bestSellingProducts: ProductSalesSummary[];
  lowStockProducts: StockSnapshot[];
}

/**
 * Efficiently aggregates sales into daily buckets.
 */
export function buildDailySalesReport(sales: SaleRecord[]): DailySalesBucket[] {
  const buckets = new Map<string, DailySalesBucket>();

  for (const sale of sales) {
    const date = sale.timestamp.slice(0, 10); // YYYY-MM-DD
    let bucket = buckets.get(date);
    if (!bucket) {
      bucket = { date, revenue: 0, cost: 0, profit: 0 };
      buckets.set(date, bucket);
    }

    for (const line of sale.lines) {
      const revenue = line.quantity * line.unitPrice;
      const cost = line.quantity * line.unitCost;
      bucket.revenue += revenue;
      bucket.cost += cost;
      bucket.profit += revenue - cost;
    }
  }

  return Array.from(buckets.values()).sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Aggregates sales over a calendar month.
 * monthKey expected as 'YYYY-MM'.
 */
export function buildMonthlySalesReport(
  sales: SaleRecord[],
  monthKey: string
): ProfitSummary {
  const prefix = `${monthKey}-`; // e.g. '2026-01-'
  let totalRevenue = 0;
  let totalCost = 0;

  for (const sale of sales) {
    if (!sale.timestamp.startsWith(prefix)) continue;

    for (const line of sale.lines) {
      totalRevenue += line.quantity * line.unitPrice;
      totalCost += line.quantity * line.unitCost;
    }
  }

  return {
    totalRevenue,
    totalCost,
    totalProfit: totalRevenue - totalCost,
  };
}

/**
 * Product-based sales aggregation across all provided sales.
 */
export function buildProductSalesReport(sales: SaleRecord[]): ProductSalesSummary[] {
  const map = new Map<string, ProductSalesSummary>();

  for (const sale of sales) {
    for (const line of sale.lines) {
      let summary = map.get(line.productId);
      if (!summary) {
        summary = {
          productId: line.productId,
          quantitySold: 0,
          revenue: 0,
          cost: 0,
          profit: 0,
        };
        map.set(line.productId, summary);
      }

      const revenue = line.quantity * line.unitPrice;
      const cost = line.quantity * line.unitCost;
      summary.quantitySold += line.quantity;
      summary.revenue += revenue;
      summary.cost += cost;
      summary.profit += revenue - cost;
    }
  }

  return Array.from(map.values()).sort((a, b) => b.quantitySold - a.quantitySold);
}

/**
 * Overall profit summary for a set of sales.
 */
export function buildProfitSummary(sales: SaleRecord[]): ProfitSummary {
  let totalRevenue = 0;
  let totalCost = 0;

  for (const sale of sales) {
    for (const line of sale.lines) {
      totalRevenue += line.quantity * line.unitPrice;
      totalCost += line.quantity * line.unitCost;
    }
  }

  return {
    totalRevenue,
    totalCost,
    totalProfit: totalRevenue - totalCost,
  };
}

/**
 * Dashboard metrics:
 * - total sales (revenue)
 * - total profit
 * - best-selling products
 * - low-stock products based on a configurable threshold
 */
export function buildDashboardMetrics(
  sales: SaleRecord[],
  stockSnapshots: StockSnapshot[],
  lowStockThreshold: number
): DashboardMetrics {
  const productSales = buildProductSalesReport(sales);
  const profitSummary = buildProfitSummary(sales);

  const lowStockProducts = stockSnapshots
    .filter((s) => s.quantityOnHand > 0 && s.quantityOnHand <= lowStockThreshold)
    .sort((a, b) => a.quantityOnHand - b.quantityOnHand);

  return {
    totalRevenue: profitSummary.totalRevenue,
    totalProfit: profitSummary.totalProfit,
    bestSellingProducts: productSales,
    lowStockProducts,
  };
}