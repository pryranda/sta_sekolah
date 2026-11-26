import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Shared school logo preview + file picker + URL input used in both
/// Admin Sekolah Settings and Superadmin Sekolah Form.
class SchoolLogoPicker extends StatelessWidget {
  final TextEditingController logoUrlController;
  final Uint8List? pickedBytes;
  final String? pickedFileName;
  final Color accentColor;
  final void Function(Uint8List bytes, String filename) onPicked;
  final VoidCallback onClear;
  final VoidCallback? onUrlChanged;

  const SchoolLogoPicker({
    super.key,
    required this.logoUrlController,
    required this.pickedBytes,
    required this.pickedFileName,
    required this.accentColor,
    required this.onPicked,
    required this.onClear,
    this.onUrlChanged,
  });

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal membaca isi file logo'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      onPicked(file.bytes!, file.name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = logoUrlController.text.trim();
    final hasAnyLogo = pickedBytes != null || url.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final preview = Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accentColor.withOpacity(0.28)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: _buildPreviewImage(url),
                  ),
                );

                final controls = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickedBytes != null
                          ? 'File dipilih: ${pickedFileName ?? "logo"}'
                          : (url.isNotEmpty ? 'Logo sekolah aktif' : 'Belum ada logo sekolah'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Format PNG, JPG, atau WEBP (maks. 10 MB). '
                      'Upload file atau tempel URL gambar langsung.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickFile(context),
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: Text(hasAnyLogo ? 'Ganti Logo' : 'Pilih File Logo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (hasAnyLogo)
                          OutlinedButton.icon(
                            onPressed: onClear,
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade200),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );

                if (constraints.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      preview,
                      const SizedBox(height: 14),
                      controls,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    preview,
                    const SizedBox(width: 16),
                    Expanded(child: controls),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: logoUrlController,
              onChanged: (_) => onUrlChanged?.call(),
              decoration: const InputDecoration(
                labelText: 'URL Logo (opsional / terisi otomatis setelah upload)',
                hintText: 'https://... atau /uploads/logo/...',
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewImage(String url) {
    if (pickedBytes != null) {
      return Image.memory(
        pickedBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() => Center(
        child: Icon(
          Icons.school_rounded,
          size: 40,
          color: accentColor,
        ),
      );
}
