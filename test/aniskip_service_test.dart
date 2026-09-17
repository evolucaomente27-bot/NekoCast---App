import 'package:flutter_test/flutter_test.dart';
import 'package:nekocast/services/aniskip_service.dart';

void main() {
  group('AniSkipService title cleaning', () {
    test('cleans source tags and language markers', () {
      expect(
        AniSkipService.cleanAnimeTitle('[AnimeFire] Solo Leveling (Dublado)'),
        'Solo Leveling',
      );
      expect(
        AniSkipService.cleanAnimeTitle('One Piece (Legendado) [Sugoi]'),
        'One Piece',
      );
      expect(
        AniSkipService.cleanAnimeTitle('Naruto Shippuden 2ª Temporada (Dublado) - Todos os Episodios'),
        'Naruto Shippuden Season 2',
      );
    });

    test('normalizes Portuguese season indicators', () {
      expect(
        AniSkipService.cleanAnimeTitle('Jujutsu Kaisen 2ª Temporada'),
        'Jujutsu Kaisen Season 2',
      );
      expect(
        AniSkipService.cleanAnimeTitle('Bleach Parte 2'),
        'Bleach Part 2',
      );
    });
  });

  group('AniSkipService dynamic ID resolution', () {
    test('resolves MAL and AniList IDs for Solo Leveling via Kitsu', () async {
      final ids = await AniSkipService.resolveIdsByTitle('Solo Leveling');
      expect(ids.hasId, isTrue);
      expect(ids.malId, 52299);
      expect(ids.anilistId, 151807);
    });

    test('resolves skip times using animeTitle fallback', () async {
      final skipTimes = await AniSkipService.getSkipTimesMultiStrategy(
        animeTitle: 'Solo Leveling',
        episodeNumber: 1,
        episodeLengthSeconds: 1420,
      );
      expect(skipTimes.hasSkipTimes, isTrue);
      expect(skipTimes.op, isNotNull);
      expect(skipTimes.op!.start, greaterThan(0));
      expect(skipTimes.op!.end, greaterThan(skipTimes.op!.start));
    });
  });
}
