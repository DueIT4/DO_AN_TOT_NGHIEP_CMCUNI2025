import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'file_saver.dart';

class FileSaverMobile implements FileSaver {
  @override
  Future<void> saveAndLaunch(Uint8List bytes, String fileName, String mimeType) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path, type: mimeType);
  }
}

FileSaver getFileSaverImpl() => FileSaverMobile();
