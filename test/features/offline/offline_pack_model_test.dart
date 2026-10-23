import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/offline/data/models/offline_pack_model.dart';
import 'package:qvgestion_mobile/features/offline/data/models/offline_pois_export_model.dart';

void main() {
  group('OfflinePackModel Tests', () {
    test('Désérialisation correcte depuis JSON', () {
      final json = {
        'region_id': 'centre-ouagadougou',
        'nom_region': 'Région du Centre (Ouagadougou)',
        'description': 'Tuiles de la capitale',
        'taille_octets': 47185920,
        'taille_mo': 45.0,
        'version': '2026.09.1',
        'sha256_checksum': '7ca9649503bdf5b87f113c5097fd276b',
        'file_format': 'pmtiles',
        'bounding_box': [12.2, -1.65, 12.5, -1.35],
        'poi_count': 1420,
      };

      final pack = OfflinePackModel.fromJson(json);

      expect(pack.regionId, equals('centre-ouagadougou'));
      expect(pack.nomRegion, equals('Région du Centre (Ouagadougou)'));
      expect(pack.tailleMo, equals(45.0));
      expect(pack.formattedSize, equals('45.0 Mo'));
      expect(pack.poiCount, equals(1420));
      expect(pack.isDownloaded, isFalse);
      expect(pack.iconData, isNotNull);
    });

    test('copyWith met à jour les états de téléchargement', () {
      const pack = OfflinePackModel(
        regionId: 'hauts-bassins-bobo',
        nomRegion: 'Hauts-Bassins',
        description: 'Bobo',
        tailleOctets: 33554432,
        tailleMo: 32.0,
        version: '1.0.0',
        sha256Checksum: 'abc',
      );

      final downloading = pack.copyWith(
        isDownloading: true,
        downloadProgress: 0.5,
      );

      expect(downloading.isDownloading, isTrue);
      expect(downloading.downloadProgress, equals(0.5));

      final downloaded = downloading.copyWith(
        isDownloading: false,
        isDownloaded: true,
      );

      expect(downloaded.isDownloaded, isTrue);
      expect(downloaded.isDownloading, isFalse);
    });
  });

  group('OfflinePoisExportModel Tests', () {
    test('Désérialisation de l\'index compact des POIs', () {
      final json = {
        'region_id': 'centre-ouagadougou',
        'version': '2026.09.1',
        'total_pois': 1,
        'pois': [
          {
            'id': 1,
            'nom': 'Pharmacie 1200 Logements',
            'categorie_slug': 'pharmacie',
            'latitude': 12.3688,
            'longitude': -1.4988,
            'quartier': '1200 Logements',
            'telephone': '+22625360000',
          },
        ],
      };

      final export = OfflinePoisExportModel.fromJson(json);

      expect(export.regionId, equals('centre-ouagadougou'));
      expect(export.totalPois, equals(1));
      expect(export.pois.length, equals(1));
      expect(export.pois.first.nom, equals('Pharmacie 1200 Logements'));
      expect(export.pois.first.categorieSlug, equals('pharmacie'));
    });
  });
}
