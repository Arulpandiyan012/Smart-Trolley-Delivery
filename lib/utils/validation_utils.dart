class ValidationUtils {
  /// Validates if the phone number is exactly 10 digits (Indian format).
  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    final phoneRegExp = RegExp(r'^[0-9]{10}$');
    return phoneRegExp.hasMatch(phone);
  }

  /// Validates if the email format is correct.
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegExp.hasMatch(email);
  }
}
