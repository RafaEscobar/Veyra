import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

final class VaultFileIcon extends StatelessWidget {
  const VaultFileIcon({required this.fileName, super.key});

  final String fileName;

  static IconData iconFor(String fileName) {
    final String extension = path
        .extension(fileName)
        .replaceFirst('.', '')
        .toLowerCase();
    return switch (extension) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'txt' => Icons.description_outlined,
      'doc' || 'docx' => Icons.article_outlined,
      'xls' || 'xlsx' => Icons.table_chart_outlined,
      'zip' => Icons.folder_zip_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Icon(iconFor(fileName));
  }
}
