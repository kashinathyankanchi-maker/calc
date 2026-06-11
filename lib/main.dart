import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/calculator_screen.dart';
import 'screens/stats_screen.dart';
import 'calculator_logic.dart';

void main() {
  runApp(const GitHubCalculatorApp());
}

class GitHubCalculatorApp extends StatelessWidget {
  const GitHubCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitCalc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF), // GitHub Blue
          surface: Color(0xFF161B22), // GitHub Dark Card
          background: Color(0xFF0D1117), // GitHub Dark BG
        ),
        useMaterial3: true,
      ),
      home: const MainLayoutScreen(),
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _activeTabIndex = 0;
  String _expression = '';
  String _result = '0';

  // Constants
  static const Color bgColor = Color(0xFF0D1117);
  static const Color borderCol = Color(0xFF30363D);
  static const Color textMain = Color(0xFFC9D1D9);
  static const Color textMuted = Color(0xFF8B949E);
  static const Color gitBlue = Color(0xFF58A6FF);

  void _onKeyPressed(String key) {
    setState(() {
      // Map display operators to evaluator operators
      if (_expression == '0' || _expression == 'Error') {
        _expression = key;
      } else {
        // Prevent repeating operators
        final String lastChar = _expression.isNotEmpty ? _expression.substring(_expression.length - 1) : '';
        final isOperator = ['+', '-', '×', '÷', '%'].contains(key);
        final isLastOperator = ['+', '-', '×', '÷', '%'].contains(lastChar);

        if (isOperator && isLastOperator) {
          // Replace last operator with the new one
          _expression = _expression.substring(0, _expression.length - 1) + key;
        } else {
          _expression += key;
        }
      }
    });
  }

  void _onEvaluate() {
    if (_expression.isEmpty) return;
    setState(() {
      _result = CalculatorLogic.evaluate(_expression);
    });
  }

  void _onClear() {
    setState(() {
      _expression = '';
      _result = '0';
    });
  }

  void _onDelete() {
    setState(() {
      if (_expression.isNotEmpty) {
        _expression = _expression.substring(0, _expression.length - 1);
      }
    });
  }

  void _onInsertValue(String value) {
    setState(() {
      final String lastChar = _expression.isNotEmpty ? _expression.substring(_expression.length - 1) : '';
      final isLastNumber = RegExp(r'[0-9.]').hasMatch(lastChar);
      
      // If the last character in expression is a number, insert an operator first to separate them
      if (_expression.isNotEmpty && isLastNumber) {
        _expression += ' + ';
      }
      
      _expression += value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      CalculatorScreen(
        expression: _expression,
        result: _result,
        onKeyPressed: _onKeyPressed,
        onEvaluate: _onEvaluate,
        onClear: _onClear,
        onDelete: _onDelete,
      ),
      StatsScreen(
        onInsertValue: _onInsertValue,
        onSwitchToCalculator: () {
          setState(() {
            _activeTabIndex = 0;
          });
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.code, color: gitBlue, size: 24),
            const SizedBox(width: 10),
            Text(
              _activeTabIndex == 0 ? 'GitCalc' : 'GitStats Lookup',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textMain,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: borderCol,
            height: 1.0,
          ),
        ),
      ),
      body: IndexedStack(
        index: _activeTabIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: borderCol, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _activeTabIndex,
          onTap: (index) {
            setState(() {
              _activeTabIndex = index;
            });
          },
          backgroundColor: const Color(0xFF161B22),
          selectedItemColor: gitBlue,
          unselectedItemColor: textMuted,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calculate),
              activeIcon: Icon(Icons.calculate, color: gitBlue),
              label: 'Calculator',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.code),
              activeIcon: Icon(Icons.code, color: gitBlue),
              label: 'Dev Stats',
            ),
          ],
        ),
      ),
    );
  }
}
