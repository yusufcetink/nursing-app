import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';
import 'package:asli_app/features/user_management/domain/models/managed_user.dart';

final userManagementRepositoryProvider = Provider<UserManagementRepository>(
  (ref) => DioUserManagementRepository(ref.watch(apiClientProvider)),
);

abstract interface class UserManagementRepository {
  Future<List<ManagedUser>> getUsers(String search);

  Future<ManagedUser> changeRole(String userId, UserRole role);
}

final class DioUserManagementRepository implements UserManagementRepository {
  const DioUserManagementRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<ManagedUser>> getUsers(String search) async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/api/admin/users',
        queryParameters: search.trim().isEmpty
            ? null
            : {'search': search.trim()},
      );
      return (response.data ?? const [])
          .map((item) => _fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on Object {
      throw const NetworkException('Kullanıcı listesi alınamadı.');
    }
  }

  @override
  Future<ManagedUser> changeRole(String userId, UserRole role) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        '/api/admin/users/$userId/role',
        data: {'role': role.apiValue},
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return _fromJson(data);
    } on DioException catch (error) {
      final serverMessage = _serverMessage(error.response?.data);
      if (serverMessage != null) throw NetworkException(serverMessage);
      throw mapNetworkException(error);
    } on NetworkException {
      rethrow;
    } on Object {
      throw const NetworkException('Kullanıcı rolü değiştirilemedi.');
    }
  }

  static ManagedUser _fromJson(Map<String, dynamic> json) => ManagedUser(
    id: json['id'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    email: json['email'] as String,
    role: UserRole.fromApiValue(json['role'] as String),
  );

  static String? _serverMessage(Object? data) {
    if (data is! Map || data['errors'] is! List) return null;
    final errors = (data['errors'] as List).whereType<String>();
    if (errors.any((error) => error.contains('last admin'))) {
      return 'Son Admin kullanıcısının rolü değiştirilemez.';
    }
    return errors.isEmpty ? null : errors.join('\n');
  }
}

extension UserRoleApiValue on UserRole {
  String get apiValue => switch (this) {
    UserRole.student => 'Student',
    UserRole.contentEditor => 'ContentEditor',
    UserRole.admin => 'Admin',
  };

  String get displayName => switch (this) {
    UserRole.student => 'Student',
    UserRole.contentEditor => 'ContentEditor',
    UserRole.admin => 'Admin',
  };
}
