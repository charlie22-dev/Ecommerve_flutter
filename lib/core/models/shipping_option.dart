/// Static shipping tiers — not database-backed since there's no real
/// courier integration; a production version would price these from a
/// shipping-rates API/service instead of flat constants.
class ShippingOption {
  const ShippingOption({required this.id, required this.label, required this.eta, required this.cost});

  final String id;
  final String label;
  final String eta;
  final double cost;

  static const standard = ShippingOption(id: 'standard', label: 'Standard Shipping', eta: '3-5 business days', cost: 60);
  static const express = ShippingOption(id: 'express', label: 'Express Shipping', eta: '1-2 business days', cost: 150);

  static const all = [standard, express];

  /// Orders at or above this peso amount qualify for free standard shipping.
  static const freeShippingThreshold = 1500.0;

  /// Looks up a shipping option by its identifier, defaulting to standard shipping.
  static ShippingOption fromId(String id) => all.firstWhere((o) => o.id == id, orElse: () => standard);

  /// Orders at or above the free-shipping threshold get standard shipping
  /// for free; express still costs its normal rate.
  double costFor(double subtotal) => (this == standard && subtotal >= freeShippingThreshold) ? 0 : cost;
}
