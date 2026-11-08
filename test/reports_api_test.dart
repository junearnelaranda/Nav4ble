import 'package:flutter_test/flutter_test.dart';
import 'package:navable/reports_api.dart';

void main() {
  group('ReportsApi.reportTypeFor', () {
    test('maps problem categories to the database report types', () {
      expect(ReportsApi.reportTypeFor('Broken ramp'), 'Broken Ramp');
      expect(ReportsApi.reportTypeFor('Broken elevator'), 'Broken Elevator');
      expect(ReportsApi.reportTypeFor('Blocked entrance'), 'Blocked Entrance');
      expect(ReportsApi.reportTypeFor('Construction'), 'Construction');
    });

    test('files feature photos and other issues as Others', () {
      for (final category in [
        'Accessible ramp',
        'Elevator access',
        'Step-free entrance',
        'Accessible toilet',
        'Other accessibility issue',
      ]) {
        expect(ReportsApi.reportTypeFor(category), 'Others', reason: category);
      }
    });
  });

  test('reportDescription keeps the category and fits 500 characters', () {
    final short = ReportsApi.reportDescription(
      category: 'Broken ramp',
      title: 'Ayala Center Cebu',
      detail: 'Ramp at the north entrance is cracked.',
    );
    expect(
      short,
      '[Broken ramp] Ayala Center Cebu: Ramp at the north entrance is cracked.',
    );

    final long = ReportsApi.reportDescription(
      category: 'Construction',
      title: 'SM City Cebu',
      detail: 'x' * 800,
    );
    expect(long.length, 500);
    expect(long, startsWith('[Construction] SM City Cebu: '));
  });

  group('ReportsApi.suggestedPlaceRow', () {
    test('builds a pending place from the pinned spot', () {
      expect(
        ReportsApi.suggestedPlaceRow(
          id: 'place-1',
          name: '  Cebu IT Park Cafe ',
          coordinates: '10.330612, 123.906321',
        ),
        {
          'location_id': 'place-1',
          'location_name': 'Cebu IT Park Cafe',
          'category': 'User suggested',
          'address': '10.330612, 123.906321',
          'latitude': 10.330612,
          'longitude': 123.906321,
        },
      );
    });

    test('caps long names at 150 characters', () {
      final row = ReportsApi.suggestedPlaceRow(
        id: 'p',
        name: 'x' * 200,
        coordinates: '10, 123',
      );
      expect((row['location_name'] as String).length, 150);
    });

    test('rejects a missing pin or name', () {
      for (final (name, coordinates) in [
        ('Cafe', null),
        ('Cafe', ''),
        ('Cafe', 'not a pin'),
        ('Cafe', '91, 123'),
        ('   ', '10.3, 123.9'),
      ]) {
        expect(
          () => ReportsApi.suggestedPlaceRow(
            id: 'p',
            name: name,
            coordinates: coordinates,
          ),
          throwsA(isA<ReportsApiException>()),
          reason: '$name / $coordinates',
        );
      }
    });
  });

  group('ReportsApi.parseAnalysisResponse', () {
    test('reads detections from a successful reply', () {
      final result = ReportsApi.parseAnalysisResponse(200, {
        'image': {'width': 640, 'height': 480},
        'detections': [
          {'class': 'ramp', 'confidence': 0.9},
        ],
      });
      expect(result['image'], {'width': 640, 'height': 480});
      expect(result['detections'], [
        {'class': 'ramp', 'confidence': 0.9},
      ]);
    });

    test('accepts a JSON string body', () {
      final result = ReportsApi.parseAnalysisResponse(
        200,
        '{"detections":[{"class":"elevator","confidence":0.8}]}',
      );
      expect(result['detections'], hasLength(1));
      expect(result['image'], {'width': null, 'height': null});
    });

    test('surfaces the service error message', () {
      expect(
        () => ReportsApi.parseAnalysisResponse(503, {
          'error': {
            'code': 'INFERENCE_NOT_CONFIGURED',
            'message': 'Roboflow inference is not configured yet.',
          },
        }),
        throwsA(
          isA<ReportsApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having(
                (e) => e.message,
                'message',
                'Roboflow inference is not configured yet.',
              ),
        ),
      );
    });

    test('rejects a reply without detections', () {
      expect(
        () => ReportsApi.parseAnalysisResponse(200, {'ok': true}),
        throwsA(isA<ReportsApiException>()),
      );
    });
  });

  group('ReportsApi.aiResultRows', () {
    const imageIds = ['image-a', 'image-b'];

    test('creates one unverified row per detection with a 0-100 score', () {
      final rows = ReportsApi.aiResultRows(
        imageIds: imageIds,
        analysis: const PhotoAnalysis(
          status: 'completed',
          photoSuggestions: [
            {
              'photoIndex': 0,
              'detections': [
                {'class': 'ramp', 'confidence': 0.9432},
                {'label': 'handrail', 'confidence': 0.71},
              ],
            },
            {
              'photoIndex': 1,
              'detections': [
                {'class': 'elevator', 'confidence': 0.5},
              ],
            },
          ],
        ),
      );

      expect(rows, hasLength(3));
      expect(rows[0]['image_id'], 'image-a');
      expect(rows[0]['detected_feature'], 'ramp');
      expect(rows[0]['confidence_score'], 94.32);
      expect(rows[0]['detection_status'], 'Needs Verification');
      expect(rows[0]['verified'], isFalse);
      expect(rows[1]['detected_feature'], 'handrail');
      expect(rows[2]['image_id'], 'image-b');
      expect(rows[2]['confidence_score'], 50.0);
    });

    test('records which model produced the detections', () {
      final rows = ReportsApi.aiResultRows(
        imageIds: imageIds,
        analysis: const PhotoAnalysis(
          status: 'completed',
          photoSuggestions: [
            {
              'photoIndex': 0,
              'model': 'NavAble YOLO11n (on-device)',
              'detections': [
                {'class': 'ramp', 'confidence': 0.9},
              ],
            },
            {
              'photoIndex': 1,
              'detections': [
                {'class': 'ramp', 'confidence': 0.9},
              ],
            },
          ],
        ),
      );
      expect(rows[0]['ai_model'], 'NavAble YOLO11n (on-device)');
      expect(rows[1]['ai_model'], startsWith('Roboflow'));
    });

    test('skips failed photos and malformed detections', () {
      final rows = ReportsApi.aiResultRows(
        imageIds: imageIds,
        analysis: PhotoAnalysis(
          status: 'partial',
          photoSuggestions: [
            PhotoAnalysis.failedFor(1).photoSuggestions.single,
            {
              'photoIndex': 1,
              'detections': [
                {'class': '', 'confidence': 0.9},
                {'class': 'ramp'},
                {'class': 'ramp', 'confidence': double.nan},
                'not a map',
              ],
            },
            {
              'photoIndex': 7, // no such photo
              'detections': [
                {'class': 'ramp', 'confidence': 0.9},
              ],
            },
          ],
        ),
      );

      expect(rows, isEmpty);
    });
  });

  group('MyReport', () {
    test('reads title, details and place from a stored report', () {
      final r = MyReport.fromRow({
        'report_id': 'r1',
        'report_type': 'Broken Ramp',
        'description': '[Ramp] Ramp is cracked: The left side is broken.',
        'status': 'Verified',
        'created_at': '2026-11-07T03:00:00Z',
        'locations': {'location_name': 'Ayala Center Cebu'},
      })!;
      expect(r.id, 'r1');
      expect(r.category, 'Ramp');
      expect(r.title, 'Ramp is cracked');
      expect(r.detail, 'The left side is broken.');
      expect(r.placeName, 'Ayala Center Cebu');
      expect(r.status, ReportStatus.verified);
    });

    test('plain descriptions and unknown statuses still read', () {
      final r = MyReport.fromRow({
        'report_id': 'r2',
        'report_type': 'Others',
        'description': 'Something odd',
        'status': 'Archived',
        'created_at': '2026-11-07T03:00:00Z',
        'locations': null,
      })!;
      expect(r.title, 'Something odd');
      expect(r.category, 'Others');
      expect(r.placeName, 'a place');
      expect(r.status, ReportStatus.pending);
      expect(MyReport.fromRow({'description': 'x'}), isNull);
    });

    test('each status maps to its label', () {
      expect(ReportStatus.values.map((s) => s.label), [
        'Waiting for review',
        'Verified',
        'Resolved',
        'Not approved',
      ]);
    });
  });
}
