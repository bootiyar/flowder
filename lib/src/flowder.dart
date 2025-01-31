import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flowder/src/core/downloader_core.dart';
import 'package:flowder/src/utils/constants.dart';
import 'package:flowder/src/utils/downloader_utils.dart';

export 'core/downloader_core.dart';
export 'progress/progress.dart';
export 'utils/utils.dart';

/// Global [typedef] that returns a `int` with the current byte on download
/// and another `int` with the total of bytes of the file.
typedef ProgressCallback = void Function(int count, int total);

/// Class used as a Static Handler
/// you can call the folowwing functions.
/// - Flowder.download: Returns an instance of [DownloaderCore]
/// - Flowder.initDownload -> this used at your own risk.
class Flowder {

  static RandomAccessFile? randomAccessFile;
  /// Start a new Download progress.
  /// Returns a [DownloaderCore]
  static Future<DownloaderCore> download(
      String url, DownloaderUtils options) async {
    try {
      // ignore: cancel_subscriptions
      final t = await initDownload(url, options);
      return DownloaderCore(t.subscription,t.sink, options, url);
    } catch (e) {
      rethrow;
    }
  }

  /// Init a new Download, however this returns a [Test]
  /// use at your own risk.
  static Future<Test> initDownload(
      String url, DownloaderUtils options) async {
    var lastProgress = await options.progress.getProgress(url);
    final client = options.client ?? Dio(BaseOptions(sendTimeout: 60));
    // ignore: cancel_subscriptions
    StreamSubscription? subscription;
    try {
      isDownloading = true;
      final file = await options.file.create(recursive: true);
      final response = await client.get(
        url,
        options: Options(
            responseType: ResponseType.stream,
            headers: {HttpHeaders.rangeHeader: 'bytes=$lastProgress-'}),
      );
      final _total = int.tryParse(
              response.headers.value(HttpHeaders.contentLengthHeader)!) ??
          0;
      randomAccessFile = await file.open(mode: FileMode.writeOnlyAppend);
      subscription = response.data.stream.listen(
        (Uint8List data) async {
          subscription!.pause();
          await randomAccessFile?.writeFrom(data);
          final currentProgress = lastProgress + data.length;
          await options.progress.setProgress(url, currentProgress.toInt());
          options.progressCallback.call(currentProgress, _total);
          lastProgress = currentProgress;
          subscription.resume();
        },
        onDone: () async {
          options.onDone.call();
          await randomAccessFile?.close();
          if (options.client != null) client.close();
        },
        onError: (error) async => subscription!.pause(),
      );
      return Test(subscription!, randomAccessFile!);
    } catch (e) {
      rethrow;
    }
  }
}
class Test{
  StreamSubscription<dynamic> subscription;
  RandomAccessFile sink;

  Test(this.subscription,this.sink);
}
