import { InventoryError, InventoryLedger } from '../domain/inventory';

describe('InventoryLedger - stock and costing', () => {
  it('starts with zero quantity and cost for new products', () => {
    const ledger = new InventoryLedger();

    const snapshot = ledger.getSnapshot('P1');

    expect(snapshot.quantityOnHand).toBe(0);
    expect(snapshot.averageUnitCost).toBe(0);
    expect(snapshot.lastUpdated).toBeNull();
  });

  it('increases stock and sets cost on first purchase invoice', () => {
    const ledger = new InventoryLedger();

    const snapshot = ledger.recordPurchaseInvoiceLine('P1', 10, 5);

    expect(snapshot.quantityOnHand).toBe(10);
    expect(snapshot.averageUnitCost).toBe(5);
  });

  it('calculates weighted average cost across multiple purchases', () => {
    const ledger = new InventoryLedger();

    // First purchase: 10 units @ 5
    ledger.recordPurchaseInvoiceLine('P1', 10, 5);
    // Second purchase: 20 units @ 8
    const snapshot = ledger.recordPurchaseInvoiceLine('P1', 20, 8);

    // Total quantity = 30
    expect(snapshot.quantityOnHand).toBe(30);
    // Average cost = (10*5 + 20*8) / 30 = (50 + 160) / 30 = 210 / 30 = 7
    expect(snapshot.averageUnitCost).toBeCloseTo(7);
  });

  it('decreases stock on sale and keeps average cost until stock reaches zero', () => {
    const ledger = new InventoryLedger();

    ledger.recordPurchaseInvoiceLine('P1', 10, 5);
    ledger.recordPurchaseInvoiceLine('P1', 10, 7); // average cost = 6

    // Sale of 5 units
    const afterSale = ledger.recordSale('P1', 5, 'sale');

    expect(afterSale.quantityOnHand).toBe(15);
    expect(afterSale.averageUnitCost).toBeCloseTo(6);

    // Sell remaining 15 units, stock reaches zero and cost resets
    const afterSecondSale = ledger.recordSale('P1', 15, 'sale');

    expect(afterSecondSale.quantityOnHand).toBe(0);
    expect(afterSecondSale.averageUnitCost).toBe(0);
  });

  it('decreases stock on quick sale same as normal sale', () => {
    const ledger = new InventoryLedger();

    ledger.recordPurchaseInvoiceLine('P1', 10, 5);

    const afterQuickSale = ledger.recordSale('P1', 3, 'quickSale');

    expect(afterQuickSale.quantityOnHand).toBe(7);
    expect(afterQuickSale.averageUnitCost).toBe(5);
  });

  it('prevents sale when stock is insufficient', () => {
    const ledger = new InventoryLedger();

    ledger.recordPurchaseInvoiceLine('P1', 5, 10);

    expect(() => ledger.recordSale('P1', 6, 'sale')).toThrow(InventoryError);
    try {
      ledger.recordSale('P1', 6, 'sale');
    } catch (err) {
      const error = err as InventoryError;
      expect(error.code).toBe('INSUFFICIENT_STOCK');
    }
  });

  it('validates purchase quantities and costs', () => {
    const ledger = new InventoryLedger();

    expect(() => ledger.recordPurchaseInvoiceLine('P1', 0, 10)).toThrow(InventoryError);
    expect(() => ledger.recordPurchaseInvoiceLine('P1', -5, 10)).toThrow(InventoryError);
    expect(() => ledger.recordPurchaseInvoiceLine('P1', 5, -1)).toThrow(InventoryError);
  });

  it('validates sale quantities', () => {
    const ledger = new InventoryLedger();

    ledger.recordPurchaseInvoiceLine('P1', 5, 10);

    expect(() => ledger.recordSale('P1', 0, 'sale')).toThrow(InventoryError);
    expect(() => ledger.recordSale('P1', -1, 'sale')).toThrow(InventoryError);
  });

  it('records cost history entries for purchases, sales and adjustments', () => {
    const ledger = new InventoryLedger();

    ledger.recordPurchaseInvoiceLine('P1', 10, 5);
    ledger.recordSale('P1', 4, 'sale');
    ledger.recordAdjustment('P1', 2);

    const history = ledger.getCostHistory('P1');

    expect(history).toHaveLength(3);
    expect(history[0].type).toBe('purchase');
    expect(history[0].quantityChange).toBe(10);
    expect(history[0].unitCost).toBe(5);

    expect(history[1].type).toBe('sale');
    expect(history[1].quantityChange).toBe(-4);
    expect(history[1].unitCost).toBe(5);

    expect(history[2].type).toBe('adjustment');
    expect(history[2].quantityChange).toBe(2);
    expect(history[2].unitCost).toBe(5);
  });

  it('supports generic recordMovement for purchase, sale, quick sale and adjustments', () => {
    const ledger = new InventoryLedger();

    ledger.recordMovement({
      productId: 'P1',
      quantity: 10,
      type: 'purchase',
      timestamp: new Date(),
      unitCost: 5,
    });

    ledger.recordMovement({
      productId: 'P1',
      quantity: 3,
      type: 'sale',
      timestamp: new Date(),
    });

    ledger.recordMovement({
      productId: 'P1',
      quantity: 2,
      type: 'quickSale',
      timestamp: new Date(),
    });

    ledger.recordMovement({
      productId: 'P1',
      quantity: 1,
      type: 'adjustment',
      timestamp: new Date(),
    });

    const snapshot = ledger.getSnapshot('P1');
    expect(snapshot.quantityOnHand).toBe(6);

    const history = ledger.getCostHistory('P1');
    expect(history.map((h) => h.type)).toEqual(['purchase', 'sale', 'quickSale', 'adjustment']);
  });
});