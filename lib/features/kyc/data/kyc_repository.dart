import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  return KycRepository(ref.watch(apiClientProvider));
});

class KycRepository {
  KycRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> getCountries() async {
    final res = await _api.get<List<dynamic>>(ApiEndpoints.kycCountries);
    return (res.data ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getStatus() async {
    final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.kycStatus);
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> updateProfile({
    required String countryCode,
    required String phoneNumber,
  }) async {
    final res = await _api.put<Map<String, dynamic>>(
      ApiEndpoints.kycProfile,
      data: {
        'countryCode': countryCode,
        'phoneNumber': phoneNumber.trim(),
      },
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> verifyNigeriaIdentity({
    required String method, // 'bvn' | 'nin'
    required String idNumber,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.kycIdentityNigeria,
      data: {'method': method, 'idNumber': idNumber.trim()},
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> uploadInternationalIdentity({
    required String documentType, // 'passport' | 'drivers_license'
    required File frontFile,
    File? backFile,
  }) async {
    final formData = FormData.fromMap({
      'documentType': documentType,
      'front': await MultipartFile.fromFile(frontFile.path),
      if (backFile != null)
        'back': await MultipartFile.fromFile(backFile.path),
    });
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.kycIdentityInternational,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> submitLiveness(File selfieFile) async {
    final formData = FormData.fromMap({
      'selfie': await MultipartFile.fromFile(selfieFile.path),
    });
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.kycLiveness,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return res.data ?? {};
  }
}
