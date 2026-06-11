import 'package:math_expressions/math_expressions.dart';

class CalculatorLogic {
  static String evaluate(String expression) {
    try {
      // Replace custom operators with standard math parser operators
      String parsedExpression = expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('%', '/100');

      Parser p = Parser();
      Expression exp = p.parse(parsedExpression);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      // Format the result to hide trailing .0 if it's an integer
      if (eval % 1 == 0) {
        return eval.toInt().toString();
      } else {
        // Limit decimal places for readability
        String resultString = eval.toString();
        if (resultString.contains('.') && resultString.length - resultString.indexOf('.') > 6) {
          return eval.toStringAsFixed(6);
        }
        return resultString;
      }
    } catch (e) {
      return 'Error';
    }
  }
}
