import '../domain/repositories/route_snapper.dart';

/// Thai texts for the route builder.
abstract final class RouteLabels {
  static String snapError(RouteSnapError e) => switch (e) {
    RouteSnapError.signedOut =>
      'เข้าสู่ระบบเพื่อให้ระบบหาเส้นทางบนถนนจริง ตอนนี้บันทึกเฉพาะรูปวาดได้',
    RouteSnapError.unavailable =>
      'เชื่อมต่อระบบหาเส้นทางไม่ได้ ลองใหม่อีกครั้ง หรือบันทึกรูปวาดไว้ก่อน',
    RouteSnapError.notConfigured => 'เซิร์ฟเวอร์ยังไม่เปิดระบบหาเส้นทาง',
    RouteSnapError.noRoute =>
      'ไม่พบถนนหรือทางเดินใกล้รูปที่วาด ลองวาดให้ใกล้ถนนมากขึ้น',
    RouteSnapError.tooLong => 'รูปยาวเกิน 100 กม. ลองวาดให้เล็กลง',
  };

  static String fit(int score) => 'เหมือนรูป $score%';

  static String detours(int count) => 'อ้อม $count ช่วง';

  static const notSnapped = 'ยังไม่ได้หาเส้นทาง';
}
