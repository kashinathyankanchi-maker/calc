import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DocumentConverterScreen extends StatefulWidget {
  const DocumentConverterScreen({super.key});
  @override
  State<DocumentConverterScreen> createState() => _DocumentConverterScreenState();
}

class _DocumentConverterScreenState extends State<DocumentConverterScreen>
    with TickerProviderStateMixin {
  // ── Theme colours ──────────────────────────────────────────────────────────
  static const _bg      = Color(0xFF0D1117);
  static const _card    = Color(0xFF161B22);
  static const _border  = Color(0xFF30363D);
  static const _text    = Color(0xFFC9D1D9);
  static const _muted   = Color(0xFF8B949E);
  static const _blue    = Color(0xFF58A6FF);
  static const _green   = Color(0xFF3FB950);
  static const _orange  = Color(0xFFF78166);
  static const _purple  = Color(0xFFD2A8FF);

  // ── State ───────────────────────────────────────────────────────────────────
  List<String>        _columns    = [];
  List<List<String>>  _rows       = [];
  String              _rawText    = '';
  bool                _isScanning = false;
  String              _errorMsg   = '';
  String              _docTitle   = '';
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  // ── Image Preprocessor ──────────────────────────────────────────────────────
  // Converts the picked image to grayscale, stretches contrast, then sharpens.
  // This dramatically improves Tesseract accuracy on low-light/camera photos.
  Future<String> _preprocessImage(String sourcePath) async {
    final bytes   = await File(sourcePath).readAsBytes();
    var   decoded = img.decodeImage(bytes);
    if (decoded == null) return sourcePath; // fallback: use original

    // 1. Grayscale — removes colour noise
    decoded = img.grayscale(decoded);

    // 2. Auto contrast stretch — makes dark text blacker, white bg whiter
    decoded = img.autoLevels(decoded);

    // 3. Sharpen — makes character edges crisper for OCR
    decoded = img.convolution(
      decoded,
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
      div: 1,
    );

    // Save preprocessed image to a temp file
    final dir      = await Directory.systemTemp.createTemp('ocr_');
    final outPath  = '${dir.path}/preprocessed.png';
    await File(outPath).writeAsBytes(img.encodePng(decoded));
    return outPath;
  }

  // ── OCR Scan ────────────────────────────────────────────────────────────────
  Future<void> _scan(ImageSource src) async {
    setState(() { _isScanning = true; _errorMsg = ''; });
    try {
      final picked = await ImagePicker().pickImage(
        source: src, maxWidth: 2048, maxHeight: 2048, imageQuality: 95);
      if (picked == null) { setState(() => _isScanning = false); return; }

      // Preprocess: grayscale + auto-contrast + sharpen
      final processedPath = await _preprocessImage(picked.path);

      // ── Tesseract OCR with both Kannada + English ──
      // psm 6 = uniform block of text (best for tables)
      // oem 1 = LSTM neural network engine (most accurate)
      final raw = await FlutterTesseractOcr.extractText(
        processedPath,
        language: 'kan+eng',
        args: {
          'preserve_interword_spaces': '1',
          'psm': '6',
          'oem': '1',
        },
      ) ?? '';

      // Clean up temp file
      try { await File(processedPath).delete(); } catch (_) {}

      setState(() { _rawText = raw.trim(); });
      if (raw.trim().isEmpty) {
        setState(() { _errorMsg = 'No text detected — try a clearer, well-lit image.'; _isScanning = false; });
        return;
      }
      _parseToTable(raw.trim());
      setState(() => _isScanning = false);
      _fadeCtrl.reset(); _fadeCtrl.forward();
    } catch (e) {
      setState(() { _errorMsg = 'Error: $e'; _isScanning = false; });
    }
  }

  // ── Smart Table Parser ──────────────────────────────────────────────────────
  void _parseToTable(String text) {
    // Clean up common Tesseract noise caused by table grid lines (| and _)
    final cleanedText = text.replaceAll(RegExp(r'[|_]+'), ' ');

    final lines = cleanedText.split(RegExp(r'[\n\r]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return;

    // Split each line into cells using 3+ spaces or tabs as delimiter
    // 3 spaces is safer to avoid splitting single names with a double-space typo
    final split = lines.map((l) => l.split(RegExp(r'\t+|\s{3,}'))).toList();

    // Determine max column count to NEVER lose data
    final counts = split.map((r) => r.length).toList()..sort();
    final colCount = counts.last; // max columns

    // Normalise rows to colCount cells
    final rows = split.map((r) {
      final trimmed = r.map((c) => c.trim()).toList();
      while (trimmed.length < colCount) trimmed.add('');
      return trimmed.take(colCount).toList();
    }).toList();

    if (rows.isEmpty) return;

    // Detect if first row is a header (contains mostly non-numeric text)
    final firstRow = rows.first;
    final numericCount = firstRow.where((c) => RegExp(r'^[\d.,\-+]+$').hasMatch(c.trim())).length;
    final isHeader = numericCount < firstRow.length / 2 && rows.length > 1;

    setState(() {
      if (isHeader) {
        _columns = firstRow;
        _rows    = rows.sublist(1);
      } else {
        _columns = List.generate(colCount, (i) => 'Column ${i + 1}');
        _rows    = rows;
      }
    });
  }

  int _mode(List<int> list) {
    if (list.isEmpty) return 1;
    final freq = <int, int>{};
    for (final v in list) freq[v] = (freq[v] ?? 0) + 1;
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── Edit helpers ────────────────────────────────────────────────────────────
  Future<void> _editCell(int row, int col) async {
    final ctrl   = TextEditingController(text: _rows[row][col]);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit Cell', style: GoogleFonts.inter(color: _text, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: GoogleFonts.inter(color: _text, fontSize: 14),
          decoration: InputDecoration(
            filled: true, fillColor: _bg,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _blue, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: _muted))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: _blue),
            child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) setState(() => _rows[row][col] = result);
  }

  Future<void> _editColumnName(int col) async {
    final ctrl   = TextEditingController(text: _columns[col]);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Rename Column', style: GoogleFonts.inter(color: _text, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: GoogleFonts.inter(color: _text),
          decoration: InputDecoration(
            filled: true, fillColor: _bg,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _purple, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: _muted))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: _purple),
            child: Text('Rename', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.trim().isNotEmpty) setState(() => _columns[col] = result.trim());
  }

  void _addRow() => setState(() => _rows.add(List.filled(_columns.length, '')));

  void _deleteRow(int i) => setState(() => _rows.removeAt(i));

  void _addColumn() => setState(() {
    _columns.add('Column ${_columns.length + 1}');
    for (final row in _rows) row.add('');
  });

  void _deleteColumn(int col) {
    if (_columns.length <= 1) return;
    setState(() {
      _columns.removeAt(col);
      for (final row in _rows) row.removeAt(col);
    });
  }

  void _clearAll() => setState(() { _columns = []; _rows = []; _rawText = ''; _errorMsg = ''; _docTitle = ''; });

  // ── Export Excel ────────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    if (_columns.isEmpty) { _snack('No data to export!', Colors.orange); return; }
    try {
      final wb    = Excel.createExcel();
      final sheet = wb[_docTitle.isEmpty ? 'Sheet1' : _docTitle];

      // Header row with bold style
      final headerStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1F6FEB'),
        horizontalAlign: HorizontalAlign.Center,
      );
      final headerRow = _columns.map((c) {
        final cell = TextCellValue(c);
        return cell;
      }).toList();
      sheet.appendRow(headerRow);
      // Apply header style
      for (int c = 0; c < _columns.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = headerStyle;
      }

      // Data rows
      for (int r = 0; r < _rows.length; r++) {
        final rowData = _rows[r].map((cell) {
          final num = double.tryParse(cell.replaceAll(',', '.'));
          return num != null ? DoubleCellValue(num) : TextCellValue(cell);
        }).toList();
        sheet.appendRow(rowData);
        // Alternating row background
        if (r.isEven) {
          final altStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F6F8FA'));
          for (int c = 0; c < _rows[r].length; c++) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).cellStyle = altStyle;
          }
        }
      }

      // Auto-fit columns (approximate)
      for (int c = 0; c < _columns.length; c++) {
        sheet.setColumnWidth(c, 18.0);
      }

      final bytes = wb.encode();
      if (bytes == null) { _snack('Failed to generate Excel file.', Colors.red); return; }

      final dir    = await getTemporaryDirectory();
      final title  = (_docTitle.isEmpty ? 'document' : _docTitle).replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final file   = File('${dir.path}/$title.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Exported: $title.xlsx');
    } catch (e) {
      _snack('Excel export failed: $e', Colors.red);
    }
  }

  // ── Export PDF ──────────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    if (_columns.isEmpty) { _snack('No data to export!', Colors.orange); return; }

    final headCtrl = TextEditingController(text: _docTitle);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('PDF Headline', style: GoogleFonts.inter(color: _text, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter the title for your PDF document.', style: GoogleFonts.inter(color: _muted, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: headCtrl, autofocus: true,
            style: GoogleFonts.inter(color: _text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Sales Report — July 2026',
              hintStyle: GoogleFonts.inter(color: _muted, fontSize: 12),
              filled: true, fillColor: _bg,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _orange, width: 1.5)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: _muted))),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: Text('Export PDF', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ],
      ),
    );
    final title = headCtrl.text.trim().isEmpty ? 'Document' : headCtrl.text.trim();
    headCtrl.dispose();
    if (ok != true) return;

    final now    = DateTime.now();
    final dateFmt = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Title
          pw.Center(child: pw.Text(title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            textAlign: pw.TextAlign.center)),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text('Date: $dateFmt  ·  Rows: ${_rows.length}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey500))),
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.blueGrey300, thickness: 1),
          pw.SizedBox(height: 10),
          // Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              for (int i = 0; i < _columns.length; i++) i + 1: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _pdfCell('#', header: true, align: pw.Alignment.center),
                  ..._columns.map((c) => _pdfCell(c, header: true)),
                ],
              ),
              // Data rows
              ..._rows.asMap().entries.map((e) => pw.TableRow(
                decoration: pw.BoxDecoration(color: e.key.isEven ? PdfColors.blueGrey50 : PdfColors.white),
                children: [
                  _pdfCell('${e.key + 1}', align: pw.Alignment.center),
                  ...e.value.map((c) => _pdfCell(c)),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.blueGrey200),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('kashi app', style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey400)),
            pw.Text('Total rows: ${_rows.length}', style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey400)),
          ]),
        ],
      ),
    ));

    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(),
      name: '${title.replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _pdfCell(String text, {bool header = false, pw.Alignment align = pw.Alignment.centerLeft}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Align(alignment: align,
        child: pw.Text(text, style: pw.TextStyle(
          fontSize: 9,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : PdfColors.grey900))));

  // ── Copy as text ────────────────────────────────────────────────────────────
  void _copyText() {
    if (_rows.isEmpty) { _snack('No data to copy!', Colors.orange); return; }
    final buf = StringBuffer(_columns.join('\t') + '\n');
    for (final row in _rows) buf.writeln(row.join('\t'));
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack('Table copied as tab-separated text!', _blue);
  }

  // ── Snackbar ────────────────────────────────────────────────────────────────
  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: c, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _scannerCard(),
            const SizedBox(height: 14),
            if (_columns.isNotEmpty) ...[
              _tableTitleBar(),
              const SizedBox(height: 8),
              _tableCard(),
              const SizedBox(height: 14),
              _exportCard(),
            ],
            if (_rawText.isNotEmpty && _columns.isEmpty) _rawCard(),
          ],
        ),
      ),
    );
  }

  // ── Scanner Card ─────────────────────────────────────────────────────────
  Widget _scannerCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF1C2230), Color(0xFF161B22)]),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _blue.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.document_scanner, color: _blue, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Doc Scanner & Converter', style: GoogleFonts.inter(color: _text, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(6)),
              child: Text('PRO', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ]),
          Text('Mixed Kannada + English Support', style: GoogleFonts.inter(color: _muted, fontSize: 11)),
        ])),
        if (_columns.isNotEmpty)
          IconButton(icon: const Icon(Icons.delete_outline, color: _orange, size: 20),
            onPressed: _clearAll, tooltip: 'Clear all data'),
      ]),
      const SizedBox(height: 16),
      if (_isScanning)
        _loadingWidget()
      else ...[
        Row(children: [
          Expanded(child: _actionBtn(Icons.camera_alt_rounded, 'Scan', 'Camera', _blue, () => _scan(ImageSource.camera))),
          const SizedBox(width: 10),
          Expanded(child: _actionBtn(Icons.image_rounded, 'Upload', 'Gallery', _purple, () => _scan(ImageSource.gallery))),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFF0E68C), size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Pro Engine automatically extracts mixed Kannada and English text from any printed or handwritten image.',
              style: GoogleFonts.inter(color: _muted, fontSize: 10))),
          ]),
        ),
      ],
      if (_errorMsg.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(_errorMsg, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11))),
      ],
    ]),
  );
  Widget _actionBtn(IconData icon, String title, String sub, Color col, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: col.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withOpacity(0.35)),
        ),
        child: Column(children: [
          Icon(icon, color: col, size: 28),
          const SizedBox(height: 6),
          Text(title, style: GoogleFonts.inter(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(sub, style: GoogleFonts.inter(color: _muted, fontSize: 10)),
        ]),
      ),
    );

  Widget _loadingWidget() => Container(
    height: 80,
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 36, height: 36,
        child: CircularProgressIndicator(color: _blue, strokeWidth: 3)),
      const SizedBox(height: 10),
      Text('Scanning document…', style: GoogleFonts.inter(color: _muted, fontSize: 12)),
    ]),
  );

  // ── Table title bar ───────────────────────────────────────────────────────
  Widget _tableTitleBar() => Row(children: [
    Expanded(
      child: TextField(
        onChanged: (v) => _docTitle = v,
        controller: TextEditingController(text: _docTitle),
        style: GoogleFonts.inter(color: _text, fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'Document title (for export)…',
          hintStyle: GoogleFonts.inter(color: _muted, fontSize: 12),
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          filled: true, fillColor: _card,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _blue, width: 1.5)),
        ),
      ),
    ),
    const SizedBox(width: 8),
    Tooltip(
      message: 'Add column',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _addColumn,
        child: Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
          child: const Icon(Icons.add_box_outlined, color: _purple, size: 20)),
      ),
    ),
    const SizedBox(width: 6),
    Tooltip(
      message: 'Add row',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _addRow,
        child: Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
          child: const Icon(Icons.playlist_add, color: _green, size: 20)),
      ),
    ),
  ]);

  // ── Table Card ────────────────────────────────────────────────────────────
  Widget _tableCard() => FadeTransition(
    opacity: _fadeAnim,
    child: Container(
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFF1F2937)),
            headingTextStyle: GoogleFonts.inter(color: _blue, fontSize: 12, fontWeight: FontWeight.bold),
            dataTextStyle: GoogleFonts.firaCode(color: _text, fontSize: 12),
            dataRowColor: MaterialStateProperty.resolveWith((states) => _card),
            dividerThickness: 0.5,
            columnSpacing: 20,
            columns: [
              const DataColumn(label: Text('#')),
              ..._columns.asMap().entries.map((e) => DataColumn(
                label: GestureDetector(
                  onLongPress: () => _editColumnName(e.key),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(e.value),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _deleteColumn(e.key),
                      child: const Icon(Icons.close, size: 12, color: _orange)),
                  ]),
                ),
              )),
            ],
            rows: _rows.asMap().entries.map((rowEntry) {
              final ri = rowEntry.key;
              final row = rowEntry.value;
              return DataRow(
                color: MaterialStateProperty.all(ri.isEven ? _bg : _card),
                cells: [
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${ri + 1}', style: GoogleFonts.inter(color: _muted, fontSize: 11)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _deleteRow(ri),
                      child: const Icon(Icons.remove_circle_outline, size: 13, color: _orange)),
                  ])),
                  ...row.asMap().entries.map((cellEntry) => DataCell(
                    GestureDetector(
                      onTap: () => _editCell(ri, cellEntry.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          cellEntry.value.isEmpty ? '—' : cellEntry.value,
                          style: GoogleFonts.firaCode(
                            color: cellEntry.value.isEmpty ? _muted : _text,
                            fontSize: 12),
                        ),
                      ),
                    ),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );

  // ── Export Card ───────────────────────────────────────────────────────────
  Widget _exportCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.file_download_outlined, color: _green, size: 18),
        const SizedBox(width: 8),
        Text('Export / Convert', style: GoogleFonts.inter(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('${_rows.length} rows · ${_columns.length} cols',
          style: GoogleFonts.inter(color: _muted, fontSize: 11)),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _exportBtn(Icons.table_chart, 'Excel\n(.xlsx)', _green,    _exportExcel),
        _exportBtn(Icons.picture_as_pdf, 'PDF\n(.pdf)', _orange,   _exportPdf),
        _exportBtn(Icons.copy_all,    'Softcopy\n(Text)', _blue,   _copyText),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
        child: Row(children: [
          const Icon(Icons.info_outline, color: _muted, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Excel: opens in Google Sheets or MS Excel  ·  PDF: print or share  ·  Softcopy: copy as text for any app',
            style: GoogleFonts.inter(color: _muted, fontSize: 10))),
        ]),
      ),
    ]),
  );

  Widget _exportBtn(IconData icon, String label, Color col, VoidCallback onTap) =>
    ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
      style: ElevatedButton.styleFrom(
        backgroundColor: col,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2),
    );

  // ── Raw Text Card (when parsing fails) ───────────────────────────────────
  Widget _rawCard() => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.text_snippet_outlined, color: _muted, size: 16),
        const SizedBox(width: 8),
        Text('Detected Text (Raw)', style: GoogleFonts.inter(color: _muted, fontSize: 12, fontWeight: FontWeight.bold)),
        const Spacer(),
        GestureDetector(
          onTap: () { Clipboard.setData(ClipboardData(text: _rawText)); _snack('Raw text copied!', _blue); },
          child: const Icon(Icons.copy, color: _blue, size: 16)),
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
        child: Text(_rawText, style: GoogleFonts.firaCode(color: _muted, fontSize: 11)),
      ),
    ]),
  );
}
