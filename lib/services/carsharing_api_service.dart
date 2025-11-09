import 'dart:convert';
import 'package:dio/dio.dart';

import '../models/carsharing_offer.dart';

class CarsharingApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );

  static const String _endpoint =
      'https://api.mobidata-bw.de/.../carsharing/...';

  Future<List<CarsharingOffer>> fetchCarsharingOffers() async {
    final res = await _dio.get(_endpoint);
    dynamic data = res.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    final List<CarsharingOffer> out = [];

    if (data is List) {
      for (final item in data) {
        if (item is! Map) continue;
        final offer =
            CarsharingOffer.fromJson(Map<String, dynamic>.from(item as Map));
        if (offer != null) out.add(offer);
      }
    } else if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        for (final item in items) {
          if (item is! Map) continue;
          final offer =
              CarsharingOffer.fromJson(Map<String, dynamic>.from(item as Map));
          if (offer != null) out.add(offer);
        }
      }
    }

    return out;
  }
}
