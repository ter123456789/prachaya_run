import '../domain/services/body_metrics.dart';

extension BmiBandLabels on BmiBand {
  String get label => switch (this) {
    BmiBand.underweight => 'น้ำหนักน้อย',
    BmiBand.normal => 'สมส่วน',
    BmiBand.overweight => 'น้ำหนักเกิน',
    BmiBand.obese1 => 'อ้วนระดับ 1',
    BmiBand.obese2 => 'อ้วนระดับ 2',
  };
}

/// Zone names as in the Stitch design (Latin, mono).
String zoneName(int number) => switch (number) {
  1 => 'Active Warm-Up',
  2 => 'Fat Burn / Easy Base',
  3 => 'Aerobic',
  4 => 'Threshold',
  _ => 'Anaerobic / Max',
};

/// The zone the plan focuses on, and why.
const int kFocusZone = 2;
const String kFocusZoneHint = 'ช่วงสะสมไมล์และสร้างความทนทานแอโรบิกหลัก';

/// Buddhist-era year, e.g. 2569.
int buddhistYear(int year) => year + 543;
