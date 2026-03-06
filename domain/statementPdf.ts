import { PDFDocument, rgb, StandardFonts } from 'pdf-lib';
import { Asset } from 'expo-asset';

/**
 * Basic customer info for the statement header.
 * This is intentionally decoupled from any specific UI/domain model
 * so it can be reused across web and native.
 */
export interface StatementCustomer {
  name: string;
  code?: string | null;
  phone?: string | null;
  email?: string | null;
  workplace?: string | null;
  note?: string | null;
}

/**
 * One movement (satış / tahsilat) in the statement.
 */
export type StatementEntryType = 'sale' | 'payment';

export interface StatementEntry {
  id: string;
  type: StatementEntryType;
  /**
   * ISO date-time (e.g. 2026-01-25T10:30:00Z) or anything parsable by new Date().
   * Entries are sorted by this field for deterministic output.
   */
  timestamp: string;
  amount: number;
  description?: string | null;
  reference?: string | null;
}

/**
 * Parameters for generating a customer statement (ekstre) PDF.
 */
export interface StatementPdfParams {
  customer: StatementCustomer;
  previousBalance: number;
  entries: StatementEntry[];
  start: Date;
  end: Date;
  currencySymbol?: string; // e.g. '₺'
}

/**
 * Generate a deterministic, cross‑platform customer statement (ekstre) PDF.
 *
 * - Works on Expo (native + web).
 * - Uses Expo asset system to reliably resolve fonts from assets/fonts.
 * - Embeds the font into the PDF so the output is independent of the device.
 *
 * Returns PDF bytes as Uint8Array. The caller can:
 * - save to FileSystem
 * - share it
 * - or print it (e.g. via expo-print) on native platforms.
 */
export async function generateCustomerStatementPdf(
  params: StatementPdfParams
): Promise<Uint8Array> {
  const {
    customer,
    previousBalance,
    entries,
    start,
    end,
    currencySymbol = '₺',
  } = params;

  // Ensure deterministic ordering: oldest first, then by id
  const sortedEntries = [...entries].sort((a, b) => {
    const da = new Date(a.timestamp).getTime();
    const db = new Date(b.timestamp).getTime();
    if (da !== db) return da - db;
    return a.id.localeCompare(b.id);
  });

  const pdfDoc = await PDFDocument.create();

  // Metadata kept deterministic
  pdfDoc.setTitle(`Müşteri Ekstresi - ${customer.name}`);
  pdfDoc.setAuthor('Customer Statement Generator');
  pdfDoc.setProducer('pdf-lib');
  pdfDoc.setCreator('pdf-lib');

  // Load custom font from assets/fonts via Expo asset system.
  // If anything goes wrong, we gracefully fall back to a standard font.
  const fontBytes = await loadStatementFontBytes();
  const embeddedFont = fontBytes
    ? await pdfDoc.embedFont(fontBytes, { subset: true })
    : await pdfDoc.embedFont(StandardFonts.Helvetica);

  const fontSizeHeader = 18;
  const fontSizeSubHeader = 11;
  const fontSizeBody = 10;
  const lineHeight = 14;

  const pageMargin = 40;
  const page = pdfDoc.addPage();
  const { width, height } = page.getSize();
  let y = height - pageMargin;

  const drawText = (text: string, size: number, color = rgb(0, 0, 0)) => {
    const textWidth = embeddedFont.widthOfTextAtSize(text, size);
    const textHeight = embeddedFont.heightAtSize(size);
    if (y - textHeight < pageMargin) {
      // Add new page if not enough space
      const newPage = pdfDoc.addPage([width, height]);
      y = height - pageMargin;
      return { page: newPage, x: pageMargin, y };
    }
    page.drawText(text, {
      x: pageMargin,
      y,
      size,
      font: embeddedFont,
      color,
    });
    y -= lineHeight;
    return { page, x: pageMargin, y };
  };

  const formatMoney = (value: number): string => {
    const n = Number.isFinite(value) ? value : 0;
    return `${n.toFixed(2)} ${currencySymbol}`;
  };

  const formatDate = (d: Date): string => {
    const day = String(d.getDate()).padStart(2, '0');
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const year = d.getFullYear();
    const hours = String(d.getHours()).padStart(2, '0');
    const minutes = String(d.getMinutes()).padStart(2, '0');
    return `${day}.${month}.${year} ${hours}:${minutes}`;
  };

  const safePrevBalance = Number.isFinite(previousBalance)
    ? previousBalance
    : 0;

  let periodSalesTotal = 0;
  let periodPaymentsTotal = 0;

  for (const e of sortedEntries) {
    const amount = Number.isFinite(e.amount) ? e.amount : 0;
    if (e.type === 'sale') {
      periodSalesTotal += amount;
    } else {
      periodPaymentsTotal += amount;
    }
  }

  const endBalance = safePrevBalance + periodSalesTotal - periodPaymentsTotal;

  // Header
  drawText('Müşteri Ekstresi', fontSizeHeader);
  drawText(customer.name, fontSizeSubHeader);

  if (customer.code && customer.code.trim().length > 0) {
    drawText(`Müşteri Kodu: ${customer.code}`, fontSizeBody);
  }
  if (customer.phone && customer.phone.trim().length > 0) {
    drawText(`Telefon: ${customer.phone}`, fontSizeBody);
  }
  if (customer.email && customer.email.trim().length > 0) {
    drawText(`E-posta: ${customer.email}`, fontSizeBody);
  }
  if (customer.workplace && customer.workplace.trim().length > 0) {
    drawText(`İşyeri: ${customer.workplace}`, fontSizeBody);
  }
  if (customer.note && customer.note.trim().length > 0) {
    drawText(`Not: ${customer.note}`, fontSizeBody);
  }

  y -= lineHeight;

  // Date range
  drawText(
    `Tarih Aralığı: ${formatDate(start)} - ${formatDate(end)}`,
    fontSizeBody
  );
  y -= lineHeight;

  // Previous balance
  drawText('Önceki Bakiye:', fontSizeBody);
  drawText(formatMoney(safePrevBalance), fontSizeBody);
  y -= lineHeight;

  // Movements
  y -= lineHeight;
  drawText('Hareketler', fontSizeSubHeader);

  if (sortedEntries.length === 0) {
    drawText('Seçilen aralıkta hareket yok', fontSizeBody);
  } else {
    for (const entry of sortedEntries) {
      const date = new Date(entry.timestamp);
      const dateLabel = formatDate(date);

      const isSale = entry.type === 'sale';
      const label = isSale ? 'Satış' : 'Tahsilat';

      const baseLine = `${label} - ${dateLabel}`;
      drawText(baseLine, fontSizeBody);

      const amountText = isSale
        ? formatMoney(entry.amount)
        : `- ${formatMoney(entry.amount)}`;
      drawText(`Tutar: ${amountText}`, fontSizeBody);

      if (entry.reference && entry.reference.trim().length > 0) {
        drawText(`Ref: ${entry.reference}`, fontSizeBody);
      }
      if (entry.description && entry.description.trim().length > 0) {
        drawText(`Açıklama: ${entry.description}`, fontSizeBody);
      }

      // Divider
      const dividerY = y + 4;
      if (dividerY - 1 > pageMargin) {
        page.drawLine({
          start: { x: pageMargin, y: dividerY },
          end: { x: width - pageMargin, y: dividerY },
          thickness: 0.5,
          color: rgb(0.8, 0.8, 0.8),
        });
      }
      y -= lineHeight;
    }
  }

  // Period summary
  y -= lineHeight;
  drawText('Dönem Özeti', fontSizeSubHeader);
  drawText(
    `Dönem Satış Toplamı: ${formatMoney(periodSalesTotal)}`,
    fontSizeBody
  );
  drawText(
    `Dönem Tahsilat Toplamı: - ${formatMoney(periodPaymentsTotal)}`,
    fontSizeBody
  );
  drawText(`Önceki Bakiye: ${formatMoney(safePrevBalance)}`, fontSizeBody);

  y -= lineHeight;
  drawText(
    `Dönem Sonu Bakiye: ${formatMoney(endBalance)}`,
    fontSizeBody,
  );

  const pdfBytes = await pdfDoc.save();
  return pdfBytes;
}

/**
 * Load the statement font from assets/fonts using Expo's asset system.
 *
 * - Uses Asset.fromModule(require('...')) so the bundler knows about the file.
 * - Calls downloadAsync() to ensure it exists on device (native).
 * - Uses fetch() on the resolved URI to obtain raw bytes for pdf-lib.
 *
 * Returns:
 * - Uint8Array of font bytes if loading succeeds.
 * - null if anything fails (caller falls back to a standard font).
 */
async function loadStatementFontBytes(): Promise<Uint8Array | null> {
  try {
    // This path is resolved relative to this file at build time by Metro.
    // Ensure the font file exists at assets/fonts/SpaceMono-Regular.ttf.
    const fontModule = require('../assets/fonts/SpaceMono-Regular.ttf');
    const asset = Asset.fromModule(fontModule);

    // Ensure the asset is available locally (no-op if already downloaded)
    await asset.downloadAsync();

    const uri = asset.localUri ?? asset.uri;
    if (!uri) {
      return null;
    }

    const res = await fetch(uri);
    if (!res.ok) {
      console.error?.(
        'statementPdf: loadStatementFontBytes fetch failed',
        res.status,
        res.statusText
      );
      return null;
    }

    const buffer = await res.arrayBuffer();
    return new Uint8Array(buffer);
  } catch (error: unknown) {
    // Log real error details before falling back to standard font so that
    // the root cause can be inspected in logs.
    try {
      console.error?.('statementPdf: loadStatementFontBytes error', error);
      if (error instanceof Error) {
        console.error?.('statementPdf error message:', error.message);
        console.error?.('statementPdf stack:', error.stack);
      }
    } catch {
      // Avoid throwing from logging itself.
    }
    // Any failure here should not break PDF creation;
    // the caller will fall back to a built‑in font.
    return null;
  }
}