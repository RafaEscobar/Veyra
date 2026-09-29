import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/features/files/presentation/widgets/vault_file_icon.dart';

void main() {
  test('maps supported extensions and falls back for unknown types', () {
    expect(VaultFileIcon.iconFor('report.PDF'), Icons.picture_as_pdf_outlined);
    expect(VaultFileIcon.iconFor('notes.txt'), Icons.description_outlined);
    expect(VaultFileIcon.iconFor('letter.docx'), Icons.article_outlined);
    expect(VaultFileIcon.iconFor('budget.xlsx'), Icons.table_chart_outlined);
    expect(VaultFileIcon.iconFor('backup.zip'), Icons.folder_zip_outlined);
    expect(
      VaultFileIcon.iconFor('unknown.bin'),
      Icons.insert_drive_file_outlined,
    );
  });
}
