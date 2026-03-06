export type StockMovementType = 'purchase' | 'sale' | 'quickSale' | 'adjustment';

export class InventoryError extends Error {
  readonly code: 'INSUFFICIENT_STOCK' | 'INVALID_QUANTITY' | 'INVALID_COST';

  constructor(code: InventoryError['code'], message: string) {
    super(message);
    this.code = code;
  }
}

export interface StockSnapshot {
  productId: string;
  quantityOnHand: number;
  averageUnitCost: number;
  lastUpdated: Date | null;
}

export interface CostHistoryEntry {
  productId: string;
  timestamp: Date;
  quantityChange: number;
  unitCost: number;
  resultingAverageUnitCost: number;
  type: StockMovementType;
}

export interface StockMovement {
  productId: string;
  quantity: number;
  timestamp: Date;
  type: StockMovementType;
  unitCost?: number;
}

/**
 * InventoryLedger encapsulates all stock and costing rules.
 *
 * It is an in-memory domain service responsible for:
 * - tracking stock quantities per product
 * - calculating and storing average cost per product
 * - maintaining cost history
 * - enforcing business rules around stock movements
 */
export class InventoryLedger {
  private readonly snapshots = new Map<string, StockSnapshot>();
  private readonly costHistory = new Map<string, CostHistoryEntry[]>();

  getSnapshot(productId: string): StockSnapshot {
    const existing = this.snapshots.get(productId);
    if (existing) {
      return { ...existing };
    }

    const snapshot: StockSnapshot = {
      productId,
      quantityOnHand: 0,
      averageUnitCost: 0,
      lastUpdated: null,
    };
    this.snapshots.set(productId, snapshot);
    return { ...snapshot };
  }

  getCostHistory(productId: string): CostHistoryEntry[] {
    return (this.costHistory.get(productId) ?? []).map((entry) => ({ ...entry }));
  }

  /**
   * Record a purchase invoice line.
   *
   * Business rules:
   * - quantity must be > 0
   * - unitCost must be >= 0
   * - increases stock
   * - updates average cost using weighted average method
   */
  recordPurchaseInvoiceLine(
    productId: string,
    quantity: number,
    unitCost: number,
    timestamp: Date = new Date()
  ): StockSnapshot {
    if (quantity <= 0) {
      throw new InventoryError('INVALID_QUANTITY', 'Purchase quantity must be greater than zero.');
    }
    if (unitCost < 0) {
      throw new InventoryError('INVALID_COST', 'Unit cost cannot be negative.');
    }

    const snapshot = this.getSnapshot(productId);
    const previousQuantity = snapshot.quantityOnHand;
    const previousAverageCost = snapshot.averageUnitCost;

    const newQuantity = previousQuantity + quantity;

    let newAverageCost: number;
    if (previousQuantity === 0) {
      newAverageCost = unitCost;
    } else if (newQuantity === 0) {
      newAverageCost = 0;
    } else {
      newAverageCost =
        (previousQuantity * previousAverageCost + quantity * unitCost) / newQuantity;
    }

    const updatedSnapshot: StockSnapshot = {
      ...snapshot,
      quantityOnHand: newQuantity,
      averageUnitCost: newAverageCost,
      lastUpdated: timestamp,
    };

    this.snapshots.set(productId, updatedSnapshot);
    this.appendCostHistory({
      productId,
      timestamp,
      quantityChange: quantity,
      unitCost,
      resultingAverageUnitCost: newAverageCost,
      type: 'purchase',
    });

    return { ...updatedSnapshot };
  }

  /**
   * Record a sale or quick sale.
   *
   * Business rules:
   * - quantity must be > 0
   * - stock on hand must be sufficient; otherwise the operation is rejected
   * - decreases stock
   * - uses current average cost as the cost for the outgoing stock
   */
  recordSale(
    productId: string,
    quantity: number,
    type: Extract<StockMovementType, 'sale' | 'quickSale'>,
    timestamp: Date = new Date()
  ): StockSnapshot {
    if (quantity <= 0) {
      throw new InventoryError('INVALID_QUANTITY', 'Sale quantity must be greater than zero.');
    }

    const snapshot = this.getSnapshot(productId);

    if (snapshot.quantityOnHand < quantity) {
      throw new InventoryError(
        'INSUFFICIENT_STOCK',
        `Insufficient stock for product ${productId}. Requested: ${quantity}, available: ${snapshot.quantityOnHand}.`
      );
    }

    const newQuantity = snapshot.quantityOnHand - quantity;
    const newAverageCost = newQuantity === 0 ? 0 : snapshot.averageUnitCost;

    const updatedSnapshot: StockSnapshot = {
      ...snapshot,
      quantityOnHand: newQuantity,
      averageUnitCost: newAverageCost,
      lastUpdated: timestamp,
    };

    this.snapshots.set(productId, updatedSnapshot);
    this.appendCostHistory({
      productId,
      timestamp,
      quantityChange: -quantity,
      unitCost: snapshot.averageUnitCost,
      resultingAverageUnitCost: newAverageCost,
      type,
    });

    return { ...updatedSnapshot };
  }

  /**
   * Generic stock movement handler, if you need a single entry point.
   */
  recordMovement(movement: StockMovement): StockSnapshot {
    const { productId, quantity, type, timestamp, unitCost } = movement;

    if (type === 'purchase') {
      if (unitCost === undefined) {
        throw new InventoryError(
          'INVALID_COST',
          'Purchase movement requires a unit cost value.'
        );
      }
      return this.recordPurchaseInvoiceLine(productId, quantity, unitCost, timestamp);
    }

    if (type === 'sale' || type === 'quickSale') {
      const positiveQuantity = quantity;
      // For sales we expect positive quantities and handle the sign internally.
      return this.recordSale(productId, positiveQuantity, type, timestamp);
    }

    // For other adjustments, we allow positive or negative quantities without cost impact.
    return this.recordAdjustment(productId, quantity, timestamp);
  }

  /**
   * Record a manual stock adjustment that does not affect average cost.
   * Positive quantity increases stock, negative decreases it.
   * Still enforces that stock cannot go negative.
   */
  recordAdjustment(
    productId: string,
    quantityChange: number,
    timestamp: Date = new Date()
  ): StockSnapshot {
    if (quantityChange === 0) {
      return this.getSnapshot(productId);
    }

    const snapshot = this.getSnapshot(productId);
    const newQuantity = snapshot.quantityOnHand + quantityChange;

    if (newQuantity < 0) {
      throw new InventoryError(
        'INSUFFICIENT_STOCK',
        `Insufficient stock for product ${productId} to apply adjustment of ${quantityChange}.`
      );
    }

    const updatedSnapshot: StockSnapshot = {
      ...snapshot,
      quantityOnHand: newQuantity,
      averageUnitCost: newQuantity === 0 ? 0 : snapshot.averageUnitCost,
      lastUpdated: timestamp,
    };

    this.snapshots.set(productId, updatedSnapshot);
    this.appendCostHistory({
      productId,
      timestamp,
      quantityChange,
      unitCost: snapshot.averageUnitCost,
      resultingAverageUnitCost: updatedSnapshot.averageUnitCost,
      type: 'adjustment',
    });

    return { ...updatedSnapshot };
  }

  private appendCostHistory(entry: CostHistoryEntry): void {
    const list = this.costHistory.get(entry.productId) ?? [];
    list.push(entry);
    this.costHistory.set(entry.productId, list);
  }
}