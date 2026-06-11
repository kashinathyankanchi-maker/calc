import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CalculatorScreen extends StatelessWidget {
  final String expression;
  final String result;
  final Function(String) onKeyPressed;
  final VoidCallback onEvaluate;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  const CalculatorScreen({
    super.key,
    required this.expression,
    required this.result,
    required this.onKeyPressed,
    required this.onEvaluate,
    required this.onClear,
    required this.onDelete,
  });

  // Colors based on GitHub Dark Palette
  static const Color bgColor = Color(0xFF0D1117);
  static const Color cardColor = Color(0xFF161B22);
  static const Color borderCol = Color(0xFF30363D);
  static const Color textMain = Color(0xFFC9D1D9);
  static const Color textMuted = Color(0xFF8B949E);
  static const Color gitBlue = Color(0xFF58A6FF);
  static const Color gitGreen = Color(0xFF238636);
  static const Color gitRed = Color(0xFFDA3633);
  static const Color btnDark = Color(0xFF21262D);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Display Area
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderCol, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Expression display
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      expression.isEmpty ? '0' : expression,
                      style: GoogleFonts.firaCode(
                        fontSize: 36.0,
                        fontWeight: FontWeight.w400,
                        color: textMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  // Result display
                  Text(
                    result,
                    style: GoogleFonts.firaCode(
                      fontSize: 48.0,
                      fontWeight: FontWeight.bold,
                      color: result == 'Error' ? gitRed : gitBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Keypad Area
          Expanded(
            flex: 4,
            child: Container(
              color: cardColor,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRow(['AC', 'DEL', '%', '÷'], isOperatorRow: true),
                  _buildRow(['7', '8', '9', '×']),
                  _buildRow(['4', '5', '6', '-']),
                  _buildRow(['1', '2', '3', '+']),
                  _buildRow(['.', '0', '=', '']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys, {bool isOperatorRow = false}) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: keys.map((key) {
          if (key.isEmpty) return const Expanded(child: SizedBox());
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: _buildButton(key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButton(String text) {
    Color buttonColor;
    Color textColor;

    if (text == '=' || text == 'Evaluate') {
      buttonColor = gitGreen;
      textColor = Colors.white;
    } else if (text == 'AC') {
      buttonColor = gitRed;
      textColor = Colors.white;
    } else if (text == 'DEL') {
      buttonColor = const Color(0xFF6E7681);
      textColor = Colors.white;
    } else if (['+', '-', '×', '÷', '%'].contains(text)) {
      buttonColor = btnDark;
      textColor = gitBlue;
    } else {
      buttonColor = btnDark;
      textColor = textMain;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (text == 'AC') {
            onClear();
          } else if (text == 'DEL') {
            onDelete();
          } else if (text == '=') {
            onEvaluate();
          } else {
            onKeyPressed(text);
          }
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Ink(
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: borderCol, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 2),
                blurRadius: 4.0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
