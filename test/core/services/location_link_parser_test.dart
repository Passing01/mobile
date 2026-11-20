import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/services/location_link_parser.dart';

void main() {
  group('LocationLinkParser Tests', () {
    test('Parse une URI geo: standard envoyée par WhatsApp', () {
      final parsed = LocationLinkParser.parse(
        'geo:12.368512,-1.527145?q=12.368512,-1.527145(Place+de+la+Nation)',
      );
      expect(parsed, isNotNull);
      expect(parsed!.hasCoordinates, true);
      expect(parsed.latitude, closeTo(12.368512, 1e-6));
      expect(parsed.longitude, closeTo(-1.527145, 1e-6));
      expect(parsed.label, 'Place de la Nation');
    });

    test('Parse geo:0,0?q=lat,lon(Label) utilisé par certaines apps Android', () {
      final parsed = LocationLinkParser.parse(
        'geo:0,0?q=12.312187,-1.502617(Monument%20des%20H%C3%A9ros)',
      );
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(12.312187, 1e-6));
      expect(parsed.longitude, closeTo(-1.502617, 1e-6));
      expect(parsed.label, 'Monument des Héros');
    });

    test('Privilégie l épingle exacte Google Maps !3d!4d sur le centre caméra @', () {
      final parsed = LocationLinkParser.parse(
        'https://www.google.com/maps/place/Pharmacie+Yennenga/@12.3700,-1.5200,15z/data=!3m1!4b1!4m5!3m4!1s0x0:0x0!8m2!3d12.359201!4d-1.542802',
      );
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(12.359201, 1e-6));
      expect(parsed.longitude, closeTo(-1.542802, 1e-6));
      expect(parsed.label, 'Pharmacie Yennenga');
    });

    test('Parse un message WhatsApp partagé contenant du texte et un lien Google Maps', () {
      final parsed = LocationLinkParser.parse(
        'Retrouve moi ici à Ouaga : https://maps.google.com/?q=12.384738,-1.554870',
      );
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(12.384738, 1e-6));
      expect(parsed.longitude, closeTo(-1.554870, 1e-6));
    });

    test('Parse une URL OpenStreetMap et un lien personnalisé fasonav://', () {
      final osm = LocationLinkParser.parse(
        'https://www.openstreetmap.org/?mlat=11.177802&mlon=-4.295981#map=17/11.177802/-4.295981',
      );
      expect(osm, isNotNull);
      expect(osm!.latitude, closeTo(11.177802, 1e-6));
      expect(osm.longitude, closeTo(-4.295981, 1e-6));

      final faso = LocationLinkParser.parse(
        'fasonav://open?lat=12.376886&lon=-1.507897&name=M%C3%A9morial+Thomas+Sankara',
      );
      expect(faso, isNotNull);
      expect(faso!.latitude, closeTo(12.376886, 1e-6));
      expect(faso.longitude, closeTo(-1.507897, 1e-6));
      expect(faso.label, 'Mémorial Thomas Sankara');
    });

    test('Parse des coordonnées brutes partagées par SMS ou WhatsApp', () {
      final parsed = LocationLinkParser.parse('Ma maison : 12.345678, -1.512345');
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(12.345678, 1e-6));
      expect(parsed.longitude, closeTo(-1.512345, 1e-6));
    });
  });
}

