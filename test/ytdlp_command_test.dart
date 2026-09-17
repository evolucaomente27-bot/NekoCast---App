import 'package:flutter_test/flutter_test.dart';
import 'package:nekocast/services/download_service.dart';

void main() {
  group('DownloadService.isHlsStream', () {
    test('identifies .m3u8 playlists', () {
      expect(DownloadService.isHlsStream('https://example.com/playlist.m3u8'), isTrue);
      expect(DownloadService.isHlsStream('https://example.com/master.m3u8?token=123'), isTrue);
    });

    test('identifies disguised Akumast HLS jpg streams', () {
      expect(
        DownloadService.isHlsStream('https://akumast.net/i/some_long_hash/m.jpg'),
        isTrue,
      );
      expect(
        DownloadService.isHlsStream('https://akumast.net/i/some_long_hash/h.jpg'),
        isTrue,
      );
      expect(
        DownloadService.isHlsStream('https://akumast.net/i/some_long_hash/p.jpg'),
        isTrue,
      );
    });

    test('rejects regular mp4 and video files', () {
      expect(
        DownloadService.isHlsStream('https://example.com/video.mp4'),
        isFalse,
      );
      expect(
        DownloadService.isHlsStream('https://redirector.googlevideo.com/videoplayback?id=123'),
        isFalse,
      );
    });
  });

  group('DownloadService.generateYtDlpCommand', () {
    test('generates proper command for Akumast stream with AnimeFire referer and Origin', () {
      const url = 'https://akumast.net/i/oA5Vn_-GafAz/h.jpg';
      final cmd = DownloadService.generateYtDlpCommand(
        videoUrl: url,
        referer: 'http://127.0.0.1:49650/stream.mpd',
        outputName: 'Naruto Shippuden_EP1',
      );

      expect(cmd, contains('yt-dlp'));
      expect(cmd, contains('--referer "https://animefire.one/"'));
      expect(cmd, contains('--add-header "Origin: https://animefire.one"'));
      expect(cmd, isNot(contains('127.0.0.1')));
      expect(cmd, contains('-o "Naruto_Shippuden_EP1.%(ext)s"'));
      expect(cmd, contains('"$url"'));
    });

    test('replaces internal api.animefire.io or akumast referer with animefire web referer', () {
      const url = 'https://akumast.net/i/hash/m.jpg';
      final cmd = DownloadService.generateYtDlpCommand(
        videoUrl: url,
        referer: 'https://api.animefire.io/episode/123',
        outputName: 'One Piece EP 1000',
      );

      expect(cmd, contains('--referer "https://animefire.one/"'));
      expect(cmd, contains('--add-header "Origin: https://animefire.one"'));
    });

    test('generates command for AllAnime stream', () {
      const url = 'https://fast4.stream/video/abc';
      final cmd = DownloadService.generateYtDlpCommand(
        videoUrl: url,
        referer: 'https://allanime.to/watch/xyz',
        outputName: 'Solo Leveling EP 1',
      );

      expect(cmd, contains('--referer "https://allanime.to/watch/xyz"'));
      expect(cmd, contains('-o "Solo_Leveling_EP_1.%(ext)s"'));
    });
  });
}
