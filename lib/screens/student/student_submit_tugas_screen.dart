import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/api_service.dart';

class StudentSubmitTugasScreen extends StatefulWidget {
  final Map<String, dynamic> tugas;

  const StudentSubmitTugasScreen({super.key, required this.tugas});

  @override
  State<StudentSubmitTugasScreen> createState() => _StudentSubmitTugasScreenState();
}

class _StudentSubmitTugasScreenState extends State<StudentSubmitTugasScreen> {
  final _catatanController = TextEditingController();
  
  File? _selectedFile;
  Uint8List? _webFileBytes;
  String? _selectedFileName;
  int? _selectedFileSize;
  bool _isLoading = false;
  bool _isLoadingStatus = true;
  Map<String, dynamic>? _existingSubmission;

  @override
  void initState() {
    super.initState();
    _checkExistingSubmission();
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSubmission() async {
    setState(() => _isLoadingStatus = true);

    try {
      final headers = await ApiService.getHeaders();
      final tugasId = widget.tugas['id'];
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/student/tugas/$tugasId/submission'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('📥 Submission status: ${response.body}');
      final result = jsonDecode(response.body);

      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _existingSubmission = result['data'];
          _isLoadingStatus = false;
        });
      } else {
        setState(() => _isLoadingStatus = false);
      }
    } catch (e) {
      print('❌ Error checking submission: $e');
      setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        
        setState(() {
          _selectedFileName = file.name;
          _selectedFileSize = file.size;
          
          if (kIsWeb) {
            _webFileBytes = file.bytes;
            _selectedFile = null;
          } else {
            if (file.path != null) {
              _selectedFile = File(file.path!);
            }
            _webFileBytes = null;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ File dipilih: ${file.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal memilih file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitTugas() async {
    if (!_hasFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Pilih file terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headers = await ApiService.getHeaders();
      final tugasId = widget.tugas['id'];
      
      final uri = Uri.parse('${ApiService.baseUrl}/student/tugas/$tugasId/submit');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          _webFileBytes!,
          filename: _selectedFileName!,
        ));
      } else {
        final fileStream = http.ByteStream(_selectedFile!.openRead());
        final fileLength = await _selectedFile!.length();
        
        request.files.add(http.MultipartFile(
          'file',
          fileStream,
          fileLength,
          filename: _selectedFile!.path.split(Platform.pathSeparator).last,
        ));
      }
      
      if (_catatanController.text.isNotEmpty) {
        request.fields['catatan'] = _catatanController.text;
      }
      
      print('📤 Submitting tugas...');
      final response = await request.send();
      
      print('📥 Response status: ${response.statusCode}');
      final responseBody = await response.stream.bytesToString();
      print('📥 Response body: $responseBody');
      
      final result = jsonDecode(responseBody);
      
      setState(() => _isLoading = false);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Tugas berhasil disubmit!'),
              backgroundColor: Colors.green,
            ),
          );
          
          setState(() {
            _selectedFile = null;
            _webFileBytes = null;
            _selectedFileName = null;
            _selectedFileSize = null;
          });
          _catatanController.clear();
          
          await _checkExistingSubmission();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result['message'] ?? 'Gagal submit tugas'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error submitting: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _hasFile => kIsWeb ? _webFileBytes != null : _selectedFile != null;

  String get _displayFileName {
    if (kIsWeb) {
      return _selectedFileName ?? '-';
    } else {
      return _selectedFile?.path.split(Platform.pathSeparator).last ?? '-';
    }
  }

  double get _displayFileSizeMB {
    if (kIsWeb) {
      return (_selectedFileSize ?? 0) / 1024 / 1024;
    } else {
      try {
        return _selectedFile!.lengthSync() / 1024 / 1024;
      } catch (e) {
        return 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final judul = widget.tugas['judul'] ?? 'Tanpa Judul';
    final deskripsi = widget.tugas['deskripsi'] ?? '';
    final deadline = widget.tugas['deadline'] ?? '-';
    final namaMapel = widget.tugas['nama_mapel'] ?? '-';
    final guruNama = widget.tugas['guru_nama'] ?? '-';
    
    final deadlineDate = DateTime.tryParse(deadline);
    final isExpired = deadlineDate != null && deadlineDate.isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Submit Tugas'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingStatus
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9C27B0).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.assignment, color: Color(0xFF9C27B0), size: 32),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      judul,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      namaMapel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(Icons.person, 'Guru', guruNama),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.access_time,
                            'Deadline',
                            deadlineDate != null
                                ? '${deadlineDate.day}/${deadlineDate.month}/${deadlineDate.year} ${deadlineDate.hour.toString().padLeft(2, '0')}:${deadlineDate.minute.toString().padLeft(2, '0')}'
                                : '-',
                            color: isExpired ? Colors.red : null,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.flag,
                            'Status',
                            isExpired ? 'Expired' : 'Aktif',
                            color: isExpired ? Colors.red : Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (deskripsi.isNotEmpty) ...[
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Deskripsi Tugas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              deskripsi,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_existingSubmission != null) ...[
                    Card(
                      elevation: 2,
                      color: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.green.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Tugas Sudah Disubmit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.insert_drive_file,
                              'File',
                              _existingSubmission!['file_nama'] ?? '-',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.access_time,
                              'Submit',
                              _formatDateTime(_existingSubmission!['submitted_at']),
                            ),
                            if (_existingSubmission!['nilai'] != null) ...[
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.star,
                                'Nilai',
                                _existingSubmission!['nilai'].toString(),
                                color: Colors.amber.shade700,
                              ),
                            ],
                            if (_existingSubmission!['feedback'] != null) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Feedback Guru:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _existingSubmission!['feedback'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!isExpired) ...[
                    const Text(
                      'Upload File Tugas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _hasFile 
                                ? Colors.green.shade300 
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _hasFile ? Icons.check_circle : Icons.cloud_upload,
                              size: 48,
                              color: _hasFile 
                                  ? Colors.green 
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            if (_hasFile) ...[
                              Text(
                                _displayFileName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_displayFileSizeMB.toStringAsFixed(2)} MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Klik untuk pilih file',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PDF, DOC, DOCX, XLS, XLSX, JPG, PNG (Max 10MB)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _catatanController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        hintText: 'Tambahkan catatan untuk guru...',
                        prefixIcon: const Icon(Icons.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitTugas,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(
                          _isLoading 
                              ? 'Mengupload...' 
                              : _existingSubmission != null 
                                  ? 'Update Submission' 
                                  : 'Submit Tugas',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Maaf, deadline tugas sudah lewat.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color ?? Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '-';
    try {
      DateTime date = DateTime.parse(dateTimeStr);
      if (date.isUtc) {
        date = date.toLocal();
      }
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${date.day} ${months[date.month - 1]} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} WIB';
    } catch (e) {
      return '-';
    }
  }
}