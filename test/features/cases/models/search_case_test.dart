import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/cases/models/search_case.dart';

void main() {
  group('SearchCase model', () {
    test('converts to map and back without losing data', () {
      const original = SearchCase(
        id: 12,
        caseNumber: 'SAR-12345',
        personName: 'Test Person',
        description: 'Missing person report',
        clothing: 'Dark jacket',
        lastSeenLocation: 'Skopje',
        lastSeenAt: '2026-11-04T10:00:00',
        status: 'ACTIVE',
        createdAt: '2026-11-04T10:05:00',
      );

      final restored = SearchCase.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.caseNumber, original.caseNumber);
      expect(restored.personName, original.personName);
      expect(restored.description, original.description);
      expect(restored.clothing, original.clothing);
      expect(restored.lastSeenLocation, original.lastSeenLocation);
      expect(restored.lastSeenAt, original.lastSeenAt);
      expect(restored.status, original.status);
      expect(restored.createdAt, original.createdAt);
    });

    test('uses default values for optional fields', () {
      const original = SearchCase(
        caseNumber: 'SAR-DEFAULT',
        personName: 'Test',
        createdAt: '2026-11-04',
      );

      final restored = SearchCase.fromMap(original.toMap());

      expect(restored.description, '');
      expect(restored.clothing, '');
      expect(restored.lastSeenLocation, '');
      expect(restored.lastSeenAt, '');
      expect(restored.status, 'ACTIVE');
    });
  });

  group('CasePhoto model', () {
    test('converts to map and back without losing data', () {
      const original = CasePhoto(
        id: 7,
        caseId: 12,
        filePath: '/local/photos/image.jpg',
        fileName: 'image.jpg',
        addedAt: '2026-11-04T10:10:00',
        note: 'Reference photograph',
      );

      final restored = CasePhoto.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.caseId, original.caseId);
      expect(restored.filePath, original.filePath);
      expect(restored.fileName, original.fileName);
      expect(restored.addedAt, original.addedAt);
      expect(restored.note, original.note);
    });

    test('uses an empty note by default', () {
      const original = CasePhoto(
        caseId: 1,
        filePath: '/local/photo.jpg',
        fileName: 'photo.jpg',
        addedAt: '2026-11-04',
      );

      final restored = CasePhoto.fromMap(original.toMap());

      expect(restored.note, '');
    });
  });
}
