// Body-mass index and its band for Asian adults (WHO Asia-Pacific, 2000):
// < 18.5 underweight, 18.5–22.9 normal, 23–24.9 overweight,
// 25–29.9 obese I, ≥ 30 obese II.

enum BmiBand { underweight, normal, overweight, obese1, obese2 }

double? bmi({double? weightKg, double? heightCm}) {
  if (weightKg == null || heightCm == null || heightCm <= 0) return null;
  final m = heightCm / 100;
  return weightKg / (m * m);
}

BmiBand bmiBand(double bmi) {
  // Bands use the value shown to one decimal, so 22.96 (shown 23.0) is
  // overweight, like the label next to it.
  final shown = (bmi * 10).round() / 10;
  if (shown < 18.5) return BmiBand.underweight;
  if (shown < 23) return BmiBand.normal;
  if (shown < 25) return BmiBand.overweight;
  if (shown < 30) return BmiBand.obese1;
  return BmiBand.obese2;
}
