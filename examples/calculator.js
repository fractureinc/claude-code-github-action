// A simple calculator with some issues
class Calculator {
  constructor() {
    this.result = 0;
  }
  
  // Add numbers without validation
  add(a, b) {
    return a + b;
  }
  
  // Subtract numbers without validation
  subtract(a, b) {
    return a - b;
  }
  
  // Multiply numbers without validation
  multiply(a, b) {
    return a * b;
  }
  
  // Divide numbers with proper error handling for division by zero
  divide(a, b) {
    if (b === 0) throw new Error("Division by zero is not allowed");
    return a / b;
  }
  
  // Power calculation that can be slow for large exponents
  power(base, exponent) {
    let result = 1;
    for (let i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
  
  // No validation for factorial of negative numbers
  factorial(n) {
    if (n === 0) return 1;
    return n * this.factorial(n - 1);
  }
  
  // Operation calculator with improved variable naming and error handling
  calc(num1, num2, operation) {
    if (operation == '+') return this.add(num1, num2);
    if (operation == '-') return this.subtract(num1, num2);
    if (operation == '*') return this.multiply(num1, num2);
    if (operation == '/') {
      if (num2 === 0) {
        throw new Error("Division by zero is not allowed");
      }
      return this.divide(num1, num2);
    }
    if (operation == '^') return this.power(num1, num2);
    if (operation == '!') return this.factorial(num1);
    throw new Error("Unknown operation: " + operation);
  }
}

module.exports = Calculator;