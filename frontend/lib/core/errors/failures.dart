import 'package:dartz/dartz.dart';

sealed class Failure {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  const Failure(this.message, {this.code, this.stackTrace});
}

class AudioFailure extends Failure {
  const AudioFailure(super.message, {super.code, super.stackTrace});
}

class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.code, super.stackTrace});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code, super.stackTrace});
}

class LicenseFailure extends Failure {
  const LicenseFailure(super.message, {super.code, super.stackTrace});
}

class DeviceFailure extends Failure {
  const DeviceFailure(super.message, {super.code, super.stackTrace});
}

class SecurityFailure extends Failure {
  const SecurityFailure(super.message, {super.code, super.stackTrace});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code, super.stackTrace});
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.code, super.stackTrace});
}

typedef Result<T> = Either<Failure, T>;
