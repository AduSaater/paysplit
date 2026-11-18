class Validators {
  Validators._();

  static String? requiredField(String? value, [String label = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final regex = RegExp(r'^[\w\.\+\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Include at least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Include at least one digit';
    }
    if (!RegExp(r'[!@#\$%\^&\*\(\),.?":\{\}|<>_\-\+=\[\]\\/;~`]').hasMatch(value)) {
      return 'Include at least one special character';
    }
    return null;
  }

  static String? nuban(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Account number is required';
    }
    final digits = value.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
      return 'Enter a valid 10-digit account number';
    }
    return null;
  }

  static String? bvnOrNin(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'ID number is required';
    }
    if (!RegExp(r'^\d{11}$').hasMatch(value.trim())) {
      return 'Must be an 11-digit number';
    }
    return null;
  }

  static String? otpCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Verification code is required';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Enter the 6-digit code';
    }
    return null;
  }
}
