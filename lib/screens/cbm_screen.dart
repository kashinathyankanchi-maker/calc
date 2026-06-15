import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// --- Data Model ---
class LogEntry {
  final double girth;
  final double length;
  LogEntry({required this.girth, required this.length});
  double get volume => (girth * girth * length) / 16;
  String get volumeFormatted {
    final v = volume;
    if (v % 1 == 0) return v.toInt().toString();
    final str = v.toStringAsFixed(4);
    return str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}

class CbmScreen extends StatefulWidget {
  final Function(String) onInsertValue;
  final VoidCallback onSwitchToCalculator;
  const CbmScreen({super.key, required this.onInsertValue, required this.onSwitchToCalculator});
  @override
  State<CbmScreen> createState() => _CbmScreenState();
}

class _CbmScreenState extends State<CbmScreen> with TickerProviderStateMixin {
  final List<LogEntry> _entries = [];
  final TextEditingController _girthController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  bool _isScanning = false;
  String _scannedRawText = '';
  String _errorMessage = '';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const Color bgColor = Color(0xFF0D1117);
  static const Color cardColor = Color(0xFF161B22);
  static const Color borderCol = Color(0xFF30363D);
  static const Color textMain = Color(0xFFC9D1D9);
  static const Color textMuted = Color(0xFF8B949E);
  static const Color gitBlue = Color(0xFF58A6FF);
  static const Color gitGreen = Color(0xFF238636);
  static const Color gitRed = Color(0xFFDA3633);
  static const Color btnDark = Color(0xFF21262D);
  static const Color headerBg = Color(0xFF1C2128);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _girthController.dispose();
    _lengthController.dispose();
    _animController.dispose();
    super.dispose();
  }

  double get _totalVolume => _entries.fold(0.0, (s, e) => s + e.volume);

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _addManualRow() {
    final g = double.tryParse(_girthController.text.trim());
    final l = double.tryParse(_lengthController.text.trim());
    if (g == null || l == null || g <= 0 || l <= 0) {
      setState(() => _errorMessage = 'Enter valid positive numbers.');
      return;
    }
    setState(() {
      _entries.add(LogEntry(girth: g, length: l));
      _girthController.clear();
      _lengthController.clear();
      _errorMessage = '';
    });
    _animController..reset()..forward();
  }

  void _deleteRow(int i) => setState(() => _entries.removeAt(i));

  void _clearAll() => setState(() {
    _entries.clear();
    _errorMessage = '';
    _scannedRawText = '';
    _girthController.clear();
    _lengthController.clear();
  });

  Future<void> _pickImage(ImageSource src) async {
    setState(() { _isScanning = true; _errorMessage = ''; _scannedRawText = ''; });
    try {
      final img = await ImagePicker().pickImage(source: src, maxWidth: 1080, maxHeight: 1920);
      if (img == null) { setState(() => _isScanning = false); return; }
      final rec = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await rec.processImage(InputImage.fromFilePath(img.path));
      await rec.close();
      final raw = result.text;
      if (raw.trim().isEmpty) {
        setState(() { _errorMessage = 'No text detected. Try a clearer image.'; _isScanning = false; }); return;
      }
      final processed = raw.replaceAll(RegExp(r'(\d+),(\d+)'), r'$1.$2');
      setState(() { _scannedRawText = raw; });
      final newEntries = _parseEntries(processed);
      setState(() {
        _isScanning = false;
        if (newEntries.isNotEmpty) { _entries.addAll(newEntries); _errorMessage = ''; }
        else { _errorMessage = 'Could not extract pairs. See raw text below.'; }
      });
      if (newEntries.isNotEmpty) {
        _animController..reset()..forward();
        _snack('Scanned ${newEntries.length} log entr${newEntries.length == 1 ? "y" : "ies"}!', gitGreen);
      }
    } catch (e) {
      setState(() { _errorMessage = 'Error: $e'; _isScanning = false; });
    }
  }

  List<LogEntry> _parseEntries(String text) {
    final entries = <LogEntry>[];
    final lines = text.split(RegExp(r'[\n\r]+'));
    final numRe = RegExp(r'\b(\d+(?:\.\d+)?)\b');
    final headerRe = RegExp(r'(?:girth|length|lenght|lenth)', caseSensitive: false);
    final hasHeaders = text.toLowerCase().contains('girth') || text.toLowerCase().contains('length');

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (headerRe.hasMatch(t) && !RegExp(r'\d').hasMatch(t)) continue;
      final nums = numRe.allMatches(t)
          .map((m) => double.tryParse(m.group(0) ?? ''))
          .where((v) => v != null && v > 0).cast<double>().toList();
      if (nums.length >= 2) {
        int s = 0;
        if (hasHeaders && nums[0] == nums[0].truncateToDouble() && nums[0] <= 99 && nums.length >= 3) s = 1;
        if (s + 1 < nums.length) entries.add(LogEntry(girth: nums[s], length: nums[s + 1]));
      }
    }

    if (entries.isEmpty) {
      final all = numRe.allMatches(text)
          .map((m) => double.tryParse(m.group(0) ?? ''))
          .where((v) => v != null && v > 0).cast<double>().toList();
      for (int i = 0; i + 1 < all.length; i += 2) {
        entries.add(LogEntry(girth: all[i], length: all[i + 1]));
      }
    }
    return entries;
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: c, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerCard(),
            const SizedBox(height: 12),
            if (_entries.isNotEmpty) ...[_totalCard(), const SizedBox(height: 12)],
            _scannerCard(),
            const SizedBox(height: 12),
            _manualCard(),
            const SizedBox(height: 12),
            if (_entries.isNotEmpty) _table(),
            if (_errorMessage.isNotEmpty) ...[const SizedBox(height: 10), _errorBox()],
            if (_scannedRawText.isNotEmpty) ...[const SizedBox(height: 10), _rawBox()],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol)),
    child: Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: gitGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.forest, color: gitGreen, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Wood Log Volume Table', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: textMain)),
          const SizedBox(height: 2),
          Text('Quarter Girth  (G\u00b2 \u00d7 L) \u00f7 16', style: GoogleFonts.firaCode(fontSize: 11, color: gitBlue)),
        ])),
        if (_entries.isNotEmpty) TextButton.icon(
          onPressed: _clearAll,
          icon: const Icon(Icons.delete_sweep, size: 16, color: gitRed),
          label: Text('Clear', style: GoogleFonts.inter(color: gitRed, fontSize: 12)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        ),
      ],
    ),
  );

  Widget _totalCard() => FadeTransition(
    opacity: _fadeAnim,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: cardColor, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gitGreen, width: 1.5),
        boxShadow: [BoxShadow(color: gitGreen.withOpacity(0.12), blurRadius: 12, spreadRadius: 2)],
      ),
      child: Column(children: [
        Text('Total Log Volume', style: GoogleFonts.inter(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('${_fmt(_totalVolume)} m\u00b3', style: GoogleFonts.firaCode(color: gitGreen, fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text('${_entries.length} log${_entries.length == 1 ? "" : "s"}', style: GoogleFonts.inter(color: textMuted, fontSize: 12)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            onPressed: () { widget.onInsertValue(_fmt(_totalVolume)); widget.onSwitchToCalculator(); },
            icon: const Icon(Icons.add, size: 16),
            label: Text('Insert Total', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: gitGreen, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () {
              final t = _entries.map((e) => 'G:${e.girth}  L:${e.length}  V:${e.volumeFormatted}m\u00b3').join('\n');
              Clipboard.setData(ClipboardData(text: t));
              _snack('Table copied!', gitBlue);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: Text('Copy Table', style: GoogleFonts.inter(fontSize: 13)),
            style: OutlinedButton.styleFrom(foregroundColor: gitBlue, side: const BorderSide(color: gitBlue),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
      ]),
    ),
  );

  Widget _scannerCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.document_scanner, size: 18, color: gitBlue), const SizedBox(width: 8),
        Text('Scan or Upload Log Sheet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: textMain)),
      ]),
      const SizedBox(height: 4),
      Text('Supports printed & handwritten pages. All rows extracted automatically.',
          style: GoogleFonts.inter(fontSize: 11, color: textMuted)),
      const SizedBox(height: 6),
      Row(children: [
        const Icon(Icons.lightbulb_outline, size: 12, color: gitBlue), const SizedBox(width: 5),
        Expanded(child: Text('Tip: Write "1.10  5.00" per row, or "Girth: 1.10  Length: 5.00"',
            style: GoogleFonts.inter(fontSize: 10, color: textMuted, fontStyle: FontStyle.italic))),
      ]),
      const SizedBox(height: 12),
      if (_isScanning)
        Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            const CircularProgressIndicator(color: gitBlue, strokeWidth: 2.5),
            const SizedBox(height: 8),
            Text('Scanning…', style: GoogleFonts.inter(color: gitBlue, fontSize: 12, fontWeight: FontWeight.bold)),
          ])))
      else Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt, size: 17),
          label: Text('Scan Page', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(backgroundColor: btnDark, foregroundColor: textMain,
            padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: borderCol),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        )),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.upload_file, size: 17),
          label: Text('Upload Page', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(backgroundColor: btnDark, foregroundColor: textMain,
            padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: borderCol),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        )),
      ]),
    ]),
  );

  Widget _manualCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.edit, size: 15, color: textMuted), const SizedBox(width: 7),
        Text('Add Row Manually', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textMain))]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: _input(_girthController, 'Girth (m)')),
        const SizedBox(width: 10),
        Expanded(child: _input(_lengthController, 'Length (m)')),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _addManualRow,
          style: ElevatedButton.styleFrom(backgroundColor: gitBlue, foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Icon(Icons.add, size: 20),
        ),
      ]),
    ]),
  );

  Widget _input(TextEditingController c, String label) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
    const SizedBox(height: 5),
    TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.firaCode(color: textMain, fontSize: 13), cursorColor: gitBlue,
      decoration: InputDecoration(hintText: '0.00', hintStyle: GoogleFonts.firaCode(color: textMuted, fontSize: 13),
        fillColor: bgColor, filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderCol)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: gitBlue, width: 1.5))),
    ),
  ]);

  Widget _table() => Container(
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol)),
    child: Column(children: [
      // Header row
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: headerBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border(bottom: BorderSide(color: borderCol))),
        child: Row(children: [
          SizedBox(width: 28, child: Text('#', style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(child: Text('Girth (m)', style: GoogleFonts.inter(color: gitBlue, fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(child: Text('Length (m)', style: GoogleFonts.inter(color: gitBlue, fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(child: Text('Volume (m\u00b3)', style: GoogleFonts.inter(color: gitGreen, fontSize: 12, fontWeight: FontWeight.bold))),
          const SizedBox(width: 28),
        ]),
      ),
      // Data rows
      ListView.separated(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: borderCol),
        itemBuilder: (ctx, i) {
          final e = _entries[i];
          return Container(
            color: i.isEven ? bgColor.withOpacity(0.3) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              SizedBox(width: 28, child: Text('${i + 1}', style: GoogleFonts.inter(color: textMuted, fontSize: 12))),
              Expanded(child: Text(e.girth.toString(), style: GoogleFonts.firaCode(color: textMain, fontSize: 13, fontWeight: FontWeight.w500))),
              Expanded(child: Text(e.length.toString(), style: GoogleFonts.firaCode(color: textMain, fontSize: 13, fontWeight: FontWeight.w500))),
              Expanded(child: Text('${e.volumeFormatted} m\u00b3', style: GoogleFonts.firaCode(color: gitGreen, fontSize: 13, fontWeight: FontWeight.bold))),
              SizedBox(width: 28, child: GestureDetector(onTap: () => _deleteRow(i), child: const Icon(Icons.close, size: 15, color: gitRed))),
            ]),
          );
        },
      ),
      // Footer total
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: headerBg,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
          border: Border(top: BorderSide(color: gitGreen.withOpacity(0.5)))),
        child: Row(children: [
          const SizedBox(width: 28),
          Expanded(flex: 2, child: Text('TOTAL', style: GoogleFonts.inter(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(child: Text('${_fmt(_totalVolume)} m\u00b3', style: GoogleFonts.firaCode(color: gitGreen, fontSize: 14, fontWeight: FontWeight.bold))),
          const SizedBox(width: 28),
        ]),
      ),
    ]),
  );

  Widget _errorBox() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: gitRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: gitRed.withOpacity(0.4))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: gitRed, size: 15), const SizedBox(width: 8),
      Expanded(child: Text(_errorMessage, style: GoogleFonts.inter(color: gitRed, fontSize: 12))),
    ]),
  );

  Widget _rawBox() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(8), border: Border.all(color: borderCol)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Detected Raw Text', style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        GestureDetector(onTap: () => setState(() => _scannedRawText = ''), child: const Icon(Icons.close, size: 14, color: textMuted)),
      ]),
      const SizedBox(height: 6),
      Text(_scannedRawText, style: GoogleFonts.firaCode(color: textMain, fontSize: 11)),
    ]),
  );
}
