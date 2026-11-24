class GuestProfile {
  const GuestProfile(this.accountId, {this.displayName, this.username});

  final String accountId;
  final String? displayName;
  final String? username;
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, {this.status, this.offline = false});

  final String code;
  final int? status;
  final bool offline;
}

abstract interface class GuestSession {
  Future<GuestProfile?> cached();
  Future<GuestProfile?> restore();
  Future<GuestProfile> enter(String locale);
  Future<GuestProfile> enterQa(String handle, {required bool reset});
  Future<void> signOut();
  Future<void> close();
}
