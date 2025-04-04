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
  
  // Divide numbers without any error handling
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
  
  // Poor variable naming and lacks clarity
  calc(x, y, z) { 
    if (z == '+') return this.add(x, y);
    if (z == '-') return this.subtract(x, y);
    if (z == '*') return this.multiply(x, y);
    if (z == '/') return this.divide(x, y);
    if (z == '^') return this.power(x, y);
    if (z == '!') return this.factorial(x);
  }
}

module.exports = Calculator;
