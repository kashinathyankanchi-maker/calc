import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
            const SizedBox(height: 20.0),

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
            const SizedBox(height: 24.0),

            // Result Display Card
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
            ],
          ],
        ),
      ),
    );
  }
}
