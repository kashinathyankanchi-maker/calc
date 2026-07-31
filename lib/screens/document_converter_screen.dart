import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String              _lang       = 'en'; // 'en' = ML Kit English, 'kan' = Tesseract Kannada
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

  // ── OCR Scan ────────────────────────────────────────────────────────────────
  Future<void> _scan(ImageSource src) async {
    setState(() { _isScanning = true; _errorMsg = ''; });
    try {
      final img = await ImagePicker().pickImage(source: src, maxWidth: 2048, maxHeight: 2048, imageQuality: 90);
      if (img == null) { setState(() => _isScanning = false); return; }

      String raw;
      if (_lang == 'kan') {
        // ── Tesseract OCR (offline, supports Kannada) ──
        raw = await FlutterTesseractOcr.extractText(
          img.path,
          language: 'kan',
          args: {'preserve_interword_spaces': '1'},
        ) ?? '';
      } else {
        // ── ML Kit OCR (fast, Latin/English) ──
        final rec    = TextRecognizer(script: TextRecognitionScript.latin);
        final result = await rec.processImage(InputImage.fromFilePath(img.path));
        await rec.close();
        raw = result.text.trim();
      }

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
    final lines = text.split(RegExp(r'[\n\r]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return;

    // Split each line into cells using 2+ spaces or tabs as delimiter
    final split = lines.map((l) => l.split(RegExp(r'\t+|\s{2,}'))).toList();

    // Determine best column count (mode of all row lengths)
    final counts = split.map((r) => r.length).toList()..sort();
    final colCount = _mode(counts);

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
          Text('Document Scanner & Converter', style: GoogleFonts.inter(color: _text, fontSize: 14, fontWeight: FontWeight.bold)),
          Text('Image / Handwritten -> Excel . PDF . Softcopy', style: GoogleFonts.inter(color: _muted, fontSize: 11)),
        ])),
        if (_columns.isNotEmpty)
          IconButton(icon: const Icon(Icons.delete_outline, color: _orange, size: 20),
            onPressed: _clearAll, tooltip: 'Clear all data'),
      ]),
      const SizedBox(height: 14),
      // -- Language Selector --
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('OCR Language', style: GoogleFonts.inter(color: _muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            _langChip('en',  'English',                  'ML Kit . Fast',        _blue),
            const SizedBox(width: 8),
            _langChip('kan', '\u0c95\u0ca8\u0ccd\u0ca8\u0ca1 (Kannada)', 'Tesseract . Offline',  _orange),
          ]),
          if (_lang == 'kan') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _orange.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: _orange, size: 13),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Kannada mode uses Tesseract OCR (100% offline). Scanning may take 5-15 seconds. Works best on clear, printed Kannada text.',
                  style: GoogleFonts.inter(color: _orange, fontSize: 10))),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 14),
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
            const Icon(Icons.lightbulb_outline, color: Color(0xFFF0E68C), size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Tip: Works best with flat, well-lit images. Handwritten tables, printed sheets, and invoices all supported.',
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

  Widget _langChip(String code, String label, String sub, Color col) {
    final selected = _lang == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _lang = code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? col.withOpacity(0.15) : _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? col : _border, width: selected ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (selected) Icon(Icons.check_circle, color: col, size: 13),
              if (selected) const SizedBox(width: 4),
              Expanded(child: Text(label,
                style: GoogleFonts.inter(color: selected ? col : _text, fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Text(sub, style: GoogleFonts.inter(color: _muted, fontSize: 9)),
          ]),
        ),
      ),
    );
  }
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
