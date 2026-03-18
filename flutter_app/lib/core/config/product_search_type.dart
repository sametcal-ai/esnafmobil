enum ProductSearchType {
  api,
  scrap,
}

ProductSearchType productSearchTypeFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'scrap':
      return ProductSearchType.scrap;
    case 'api':
    default:
      return ProductSearchType.api;
  }
}

String productSearchTypeToString(ProductSearchType value) {
  switch (value) {
    case ProductSearchType.scrap:
      return 'scrap';
    case ProductSearchType.api:
      return 'api';
  }
}
