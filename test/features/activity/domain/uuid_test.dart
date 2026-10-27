import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/services/uuid.dart';

void main() {
  test(
    'uuidV5 matches RFC 4122 name-based ids (checked with Python uuid5)',
    () {
      expect(
        uuidV5('healthkit:ABC-123'),
        'cb197028-ab79-5ca6-8578-53c2c1bcd9c8',
      );
      expect(
        uuidV5('health-connect:วิ่ง'),
        'e9a16e63-e2e0-54bb-b4ef-a98ab89edabb',
      );
      // The RFC's DNS example.
      expect(
        uuidV5('python.org', namespace: '6ba7b810-9dad-11d1-80b4-00c04fd430c8'),
        '886313e1-3b8a-5372-9b90-0c9aee199e5d',
      );
    },
  );
}
