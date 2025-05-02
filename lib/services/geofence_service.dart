import 'dart:convert';
import 'package:http/http.dart' as http;

class GeofenceService {
  final String baseUrl = "https://api-vatsubsoil-dev.ggfsystem.com";

  Future<List<Map<String, dynamic>>> getPolygons() async {
    final url = Uri.parse('$baseUrl/locations?limit=1000');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['data']['locations']);
    } else {
      throw Exception('Failed to load polygons');
    }
  }

Future<Map<String, dynamic>?> getPolygonByName(String name) async {
  final url = Uri.parse('$baseUrl/locations?search=$name');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final List locations = data['data']['locations'];
    return locations.firstWhere((loc) => loc['name'] == name, orElse: () => null);
  } else {
    throw Exception('Failed to fetch detail');
  }
}
  Future<Map<String, dynamic>?> getPolygonById(String id) async {
  final url = Uri.parse('$baseUrl/locations?search=$id');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final List locations = data['data']['locations'];
    if (locations.isNotEmpty) {
      return locations.first;
    }
    return null;
  } else {
    throw Exception('Failed to fetch polygon by ID');
  }
}
}
