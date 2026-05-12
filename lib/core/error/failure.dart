abstract class Failure {
  final String message;
  final String code;

  const Failure(this.message, {this.code = 'UNKNOWN_ERROR'});

  @override
  String toString() => '$code: $message';
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code = 'SERVER_ERROR'});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code = 'NETWORK_ERROR'});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code = 'AUTH_ERROR'});
}

class UploadFailure extends Failure {
  const UploadFailure(super.message, {super.code = 'UPLOAD_ERROR'});
}
