class EmailValidator {
  EmailValidator._();

  static final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  static bool isValid(String email) {
    return _emailRegex.hasMatch(email);
  }
}
