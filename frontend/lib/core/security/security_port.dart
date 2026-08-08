import '../errors/failures.dart';

abstract class SecurityPort {
  Future<Result<void>> storeSecure(String key, String value);
  Future<Result<String?>> readSecure(String key);
  Future<Result<void>> deleteSecure(String key);
  Future<Result<bool>> containsSecure(String key);
  Future<Result<bool>> performSelfTest();
}
