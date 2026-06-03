const investmentQuantityScale = 10000;

int quantityUnits(double quantity) =>
    (quantity * investmentQuantityScale).round();

double normalizeQuantity(double quantity) =>
    quantityUnits(quantity) / investmentQuantityScale;

String formatInvestmentQuantity(double quantity) =>
    normalizeQuantity(quantity).toStringAsFixed(4);

bool quantityUnitsLte(double left, double right) =>
    quantityUnits(left) <= quantityUnits(right);
