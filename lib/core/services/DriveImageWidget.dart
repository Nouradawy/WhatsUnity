import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'GoogleDriveService.dart';


class DriveImagesGridWidget extends StatefulWidget {
  final List<String> driveUrls;
  final GoogleDriveService driveService;

  const DriveImagesGridWidget({
    required this.driveUrls,
    required this.driveService,
    super.key,
  });

  @override
  State<DriveImagesGridWidget> createState() => _DriveImagesGridWidgetState();
}

class _DriveImagesGridWidgetState extends State<DriveImagesGridWidget> {
  late Future<List<Uint8List>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = Future.wait(
      widget.driveUrls.map((url) async {
        final fileId = extractFileId(url);
        return await getCachedOrDownloadImage(
          fileId,
              () => widget.driveService.downloadFile(fileId),
        );
      }),
    ).then((list) {
      if (list.any((e) => e == null)) throw Exception('Image data is null');
      return list.cast<Uint8List>();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return const Icon(Icons.error);
        } else {
          final images = snapshot.data!;
          if (images.length == 1) {
            return Image.memory(images[0] , width: MediaQuery.sizeOf(context).width*0.95,);
          } else {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:MediaQuery.sizeOf(context).width*0.95,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Image.memory(images[index], fit: BoxFit.cover);
                },
              ),
            );
          }
        }
      },
    );
  }
}

String extractFileId(String url) {
  final regExp = RegExp(r'/d/([a-zA-Z0-9_-]+)');
  final match = regExp.firstMatch(url);
  return match != null ? match.group(1)! : '';
}

Future<Uint8List?> getCachedOrDownloadImage(
    String fileId, Future<Uint8List?> Function() downloadFn) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileId.img');
  if (await file.exists()) {
    return await file.readAsBytes();
  } else {
    final data = await downloadFn();
    if (data != null) {
      await file.writeAsBytes(data);
    }
    return data;
  }
}
