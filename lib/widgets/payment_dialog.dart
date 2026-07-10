import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PaymentDialog extends StatefulWidget {
  final String namaSiswa;
  final String periode;
  final String nominal;
  final Function(String rekening, String nomorReferensi, String catatan, Uint8List? bytes, File? file) onSubmit;
  
  const PaymentDialog({
    Key? key,
    required this.namaSiswa,
    required this.periode,
    required this.nominal,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _nomorReferensiController = TextEditingController();
  final _catatanController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  String? _selectedRekening = 'bca_1234567890'; // Default
  Uint8List? _buktiBytes;
  File? _buktiFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _nomorReferensiController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _buktiBytes = bytes;
          });
        } else {
          setState(() {
            _buktiFile = File(image.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    }
  }

  bool _hasBukti() {
    return (kIsWeb && _buktiBytes != null) || (!kIsWeb && _buktiFile != null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width > 600 ? 600 : MediaQuery.of(context).size.width - 32,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bayar Tagihan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            
            // Content (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Info Tagihan
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7BC8A4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nama: ${widget.namaSiswa}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Periode: ${widget.periode}'),
                          const SizedBox(height: 4),
                          Text('Nominal: ${widget.nominal}', 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7BC8A4), fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Pilih Rekening
                    const Text('Pilih Rekening Tujuan:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('BCA - 1234567890'),
                            subtitle: const Text('a.n. SD Muhammadiyah Cibinong'),
                            value: 'bca_1234567890',
                            groupValue: _selectedRekening,
                            onChanged: _isLoading ? null : (value) {
                              setState(() {
                                _selectedRekening = value;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('BRI - 0987654321'),
                            subtitle: const Text('a.n. SD Muhammadiyah Cibinong'),
                            value: 'bri_0987654321',
                            groupValue: _selectedRekening,
                            onChanged: _isLoading ? null : (value) {
                              setState(() {
                                _selectedRekening = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Nomor Referensi
                    TextField(
                      controller: _nomorReferensiController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Referensi/UTR (Opsional)',
                        hintText: 'Contoh: 1234567890',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Catatan
                    TextField(
                      controller: _catatanController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        hintText: 'Contoh: Pembayaran SPP Juli 2026',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    
                    // Upload Bukti
                    const Text('Upload Bukti Transfer:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _isLoading ? null : _pickImage,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: !_hasBukti()
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap untuk upload bukti transfer',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? Image.memory(_buktiBytes!, fit: BoxFit.cover, width: double.infinity, height: 150)
                                    : Image.file(_buktiFile!, fit: BoxFit.cover, width: double.infinity, height: 150),
                              ),
                      ),
                    ),
                    if (_hasBukti())
                      TextButton.icon(
                        onPressed: _isLoading ? null : () {
                          setState(() {
                            _buktiBytes = null;
                            _buktiFile = null;
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Buttons (Always visible at bottom)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading 
                    ? null 
                    : () async {
                        if (_selectedRekening == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pilih rekening tujuan terlebih dahulu')),
                          );
                          return;
                        }
                        
                        if (!_hasBukti()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Upload bukti transfer terlebih dahulu')),
                          );
                          return;
                        }
                        
                        setState(() => _isLoading = true);
                        
                        try {
                          await widget.onSubmit(
                            _selectedRekening!,
                            _nomorReferensiController.text.trim(),
                            _catatanController.text.trim(),
                            _buktiBytes,
                            _buktiFile,
                          );
                          
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                            setState(() => _isLoading = false);
                          }
                        }
                      },
                  icon: _isLoading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Mengirim...' : 'Kirim Bukti'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7BC8A4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}