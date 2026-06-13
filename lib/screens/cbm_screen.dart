import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CbmScreen extends StatefulWidget {
  final Function(String) onInsertValue;
  final VoidCallback onSwitchToCalculator;

  const CbmScreen({
    super.key,
    required this.onInsertValue,
    required this.onSwitchToCalculator,
  });

  @override
  State<CbmScreen> createState() => _CbmScreenState();
}

class _CbmScreenState extends State<CbmScreen> {
  final TextEditingController _girthController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  
  bool _useQuarterGirth = true; // true = (G*G*L)/16, false = (G*L)/16
  double? _result;
  String _errorMessage = '';
  bool _isScanning = false;
  String _scannedRawText = '';

  // Theme Constants
  static const Color bgColor = Color(0xFF0D1117);
  static const Color cardColor = Color(0xFF161B22);
  static const Color borderCol = Color(0xFF30363D);
  static const Color textMain = Color(0xFFC9D1D9);
  static const Color textMuted = Color(0xFF8B949E);
  static const Color gitBlue = Color(0xFF58A6FF);
  static const Color gitGreen = Color(0xFF238636);
  static const Color gitRed = Color(0xFFDA3633);
  static const Color btnDark = Color(0xFF21262D);

  void _calculateVolume() {
    setState(() {
      _errorMessage = '';
      _result = null;
    });

    final String girthText = _girthController.text.trim();
    final String lengthText = _lengthController.text.trim();

    if (girthText.isEmpty || lengthText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both Girth and Length';
      });
      return;
    }

    final double? girth = double.tryParse(girthText);
    final double? length = double.tryParse(lengthText);

    if (girth == null || length == null || girth <= 0 || length <= 0) {
      setState(() {
        _errorMessage = 'Please enter valid positive numbers';
      });
      return;
    }

    double volume;
    if (_useQuarterGirth) {
      // Quarter Girth standard: (G * G * L) / 16
      volume = (girth * girth * length) / 16;
    } else {
      // Linear formula: (G * L) / 16
      volume = (girth * length) / 16;
    }

    setState(() {
      _result = volume;
    });
  }

  void _clearFields() {
    setState(() {
      _girthController.clear();
      _lengthController.clear();
      _result = null;
      _errorMessage = '';
      _scannedRawText = '';
    });
  }

  String _formatResult(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    } else {
      String str = val.toString();
      if (str.contains('.') && str.length - str.indexOf('.') > 6) {
        return val.toStringAsFixed(6);
      }
      return str;
    }
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    setState(() {
      _isScanning = true;
      _errorMessage = '';
      _scannedRawText = '';
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (image == null) {
        setState(() {
          _isScanning = false;
        });
        return;
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final String rawText = recognizedText.text;
      
      if (rawText.trim().isEmpty) {
        setState(() {
          _errorMessage = 'No text could be recognized from the image. Please try again.';
          _isScanning = false;
        });
        return;
      }

      // Replace commas with periods to handle handwritten decimal style (e.g. 4,2 -> 4.2)
      final String processedText = rawText.replaceAll(RegExp(r'(\d+),(\d+)'), r'$1.$2');

      setState(() {
        _scannedRawText = rawText;
      });

      // Parse values from processed text
      final double? girth = _parseNumber(processedText, ['girth', 'g', 'gir', 'grith', 'dia', 'd']);
      final double? length = _parseNumber(processedText, ['length', 'l', 'len', 'lanth', 'langth']);

      setState(() {
        if (girth != null) {
          _girthController.text = girth.toString();
        }
        if (length != null) {
          _lengthController.text = length.toString();
        }
        _isScanning = false;
      });

      if (girth != null && length != null) {
        _calculateVolume();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully scanned Girth and Length! Volume calculated.'),
            backgroundColor: Color(0xFF238636),
          ),
        );
      } else if (girth != null || length != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partially scanned: ${girth != null ? "Girth" : "Length"} set.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Try finding any numbers in the text as a backup
        final numberRegex = RegExp(r'\b[0-9]+(?:\.[0-9]+)?\b');
        final matches = numberRegex.allMatches(processedText)
            .map((m) => double.tryParse(m.group(0) ?? ''))
            .where((val) => val != null)
            .cast<double>()
            .toList();

        if (matches.length >= 2) {
          setState(() {
            _girthController.text = matches[0].toString();
            _lengthController.text = matches[1].toString();
          });
          _calculateVolume();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Detected measurements from raw text and calculated volume.'),
              backgroundColor: Color(0xFF238636),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Could not find clear Girth and Length values in the text. Raw text shown below.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error recognizing text: $e';
        _isScanning = false;
      });
    }
  }

  double? _parseNumber(String text, List<String> keywords) {
    final String normalized = text.toLowerCase();
    
    for (final String keyword in keywords) {
      final pattern = RegExp(
        '\\b' + RegExp.escape(keyword) + r'\s*[:=\-]?\s*([0-9]+(?:\.[0-9]+)?)\b',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(normalized);
      if (match != null && match.groupCount >= 1) {
        final double? val = double.tryParse(match.group(1) ?? '');
        if (val != null && val > 0) {
          return val;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _girthController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title card info
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: borderCol, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wood Log Volume Calculator',
                    style: GoogleFonts.inter(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    'Calculate wood log volume in Cubic Meters (m³) using measurements.',
                    style: GoogleFonts.inter(
                      fontSize: 13.0,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // Result Display Card (AT THE TOP OF THE APP)
            if (_result != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: gitGreen, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: gitGreen.withOpacity(0.1),
                      blurRadius: 10.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Log Volume',
                      style: GoogleFonts.inter(
                        color: textMuted,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      '${_formatResult(_result!)} m³',
                      style: GoogleFonts.firaCode(
                        color: gitGreen,
                        fontSize: 32.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onInsertValue(_formatResult(_result!));
                        widget.onSwitchToCalculator();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Insert to Calculator'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gitGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
            ],

            // Scanner container
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: borderCol, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan or Upload Log Sheet Page',
                    style: GoogleFonts.inter(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Extract Girth and Length from printed or handwritten log page text automatically.',
                    style: GoogleFonts.inter(
                      fontSize: 12.0,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 14, color: gitBlue),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          'Tip: Write clearly like "Girth: 4.2" or "4.2 x 5" to help recognition.',
                          style: GoogleFonts.inter(
                            fontSize: 11.0,
                            color: textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  if (_isScanning)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: CircularProgressIndicator(color: gitBlue),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickAndProcessImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Scan Page'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: btnDark,
                              foregroundColor: textMain,
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                side: const BorderSide(color: borderCol, width: 1.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickAndProcessImage(ImageSource.gallery),
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Upload Page'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: btnDark,
                              foregroundColor: textMain,
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                side: const BorderSide(color: borderCol, width: 1.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_scannedRawText.isNotEmpty) ...[
                    const SizedBox(height: 12.0),
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: borderCol, width: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Detected Raw Text:',
                                style: GoogleFonts.inter(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                  color: textMuted,
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 14, color: textMuted),
                                onPressed: () {
                                  setState(() {
                                    _scannedRawText = '';
                                  });
                                },
                              )
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            _scannedRawText,
                            style: GoogleFonts.firaCode(
                              fontSize: 11.0,
                              color: textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // Form inputs
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Girth (m)',
                        style: GoogleFonts.inter(color: textMain, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6.0),
                      TextField(
                        controller: _girthController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.firaCode(color: textMain),
                        cursorColor: gitBlue,
                        decoration: InputDecoration(
                          hintText: 'Girth (m)...',
                          hintStyle: GoogleFonts.inter(color: textMuted),
                          fillColor: cardColor,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: borderCol, width: 1.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: gitBlue, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Length (m)',
                        style: GoogleFonts.inter(color: textMain, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6.0),
                      TextField(
                        controller: _lengthController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.firaCode(color: textMain),
                        cursorColor: gitBlue,
                        decoration: InputDecoration(
                          hintText: 'Length (m)...',
                          hintStyle: GoogleFonts.inter(color: textMuted),
                          fillColor: cardColor,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: borderCol, width: 1.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: gitBlue, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),

            // Formula Selection Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: borderCol, width: 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _useQuarterGirth ? 'Quarter Girth Standard' : 'Linear Formula',
                          style: GoogleFonts.inter(
                            color: textMain,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.0,
                          ),
                        ),
                        Text(
                          _useQuarterGirth ? '(Girth² × Length) ÷ 16' : '(Girth × Length) ÷ 16',
                          style: GoogleFonts.firaCode(
                            color: gitBlue,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _useQuarterGirth,
                    onChanged: (val) {
                      setState(() {
                        _useQuarterGirth = val;
                        if (_result != null) _calculateVolume();
                      });
                    },
                    activeColor: gitBlue,
                    activeTrackColor: const Color(0xFF1F6FEB).withOpacity(0.3),
                    inactiveThumbColor: textMuted,
                    inactiveTrackColor: btnDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20.0),

            // Error display
            if (_errorMessage.isNotEmpty) ...[
              Center(
                child: Text(
                  _errorMessage,
                  style: GoogleFonts.inter(color: gitRed, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16.0),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _calculateVolume,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gitBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      'Calculate',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15.0),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                ElevatedButton(
                  onPressed: _clearFields,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnDark,
                    foregroundColor: textMain,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: const BorderSide(color: borderCol, width: 1.0),
                    ),
                  ),
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
