enum CredentialsProblem { invalidEmail, passwordTooShort }

/// Same rule as the server (`docs/api.md`): passwords have at least 8 chars.
const int kMinPasswordLength = 8;

final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Checks input before calling the server. Returns null when it looks valid.
CredentialsProblem? checkCredentials(String email, String password) {
  if (!_email.hasMatch(email.trim())) return CredentialsProblem.invalidEmail;
  if (password.length < kMinPasswordLength) {
    return CredentialsProblem.passwordTooShort;
  }
  return null;
}
