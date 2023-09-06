import 'dart:async';
import 'dart:io';

import 'package:flowder/src/flowder.dart';
import 'package:flowder/src/utils/constants.dart';
import 'package:flowder/src/utils/downloader_utils.dart';

/// Class used to set/get any component from [DownloaderUtils]
/// also required to actually `start`,`stop`,`pause`,`cancel` a download.
class DownloaderCore {
  /// StreamSubscription used to link with the download streaming.
  late StreamSubscription _inner;
  RandomAccessFile? sink;

  /// Inner utils
  late final DownloaderUtils _options;

  /// Inner url
  late final String _url;

  /// Check if the download was cancelled.
  bool isCancelled = false;

  DownloaderCore(StreamSubscription inner, DownloaderUtils options, String url)
      : _inner = inner,
        _options = options,
        _url = url;

  /// Pause any current download.
  Future<void> pause() async {
    _isActive();
    await _inner.cancel();
    isDownloading = false;
  }

  /// Resume any current download, with the pending progress.
  Future<void> resume() async {
    _isActive();
    if (isDownloading) return;
    Test t = await Flowder.initDownload(_url, _options);
    _inner = t.subscription;
    sink = t.sink;
  }

  /// Cancel any current download, even if the download is [pause]
  Future<void> cancel() async {
    _isActive();
    await _inner.cancel();
    await _options.progress.resetProgress(_url);
    await sink?.close();
    if (_options.deleteOnCancel) {
      await _options.file.delete();
    }
    isCancelled = true;
    isDownloading = false;
  }

  /// Check if the download was cancelled.
  void _isActive() {
    if (isCancelled) throw StateError('Already cancelled');
  }

  /// Start a new [download] however, this download can only be access through
  /// [DownloaderCore]
  Future<DownloaderCore> download(String url, DownloaderUtils options) async {
    try {
      // ignore: cancel_subscriptions
      final t = await Flowder.initDownload(url, options);
      sink = t.sink;
      return DownloaderCore(t.subscription, options, url);
    } catch (e) {
      rethrow;
    }
  }
}
