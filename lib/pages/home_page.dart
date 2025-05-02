import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geo_fencing_vat/pages/tracking_history_page.dart';
import 'package:http/http.dart' as http;
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:geo_fencing_vat/pages/geofence_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _pageSize = 20;
  final PagingController<int, Map<String, dynamic>> _pagingController =
      PagingController(firstPageKey: 1);

  String _searchQuery = "";

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    super.initState();
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await fetchLocations(pageKey, _searchQuery);
      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLocations(int page, String search) async {
    final uri = Uri.parse(
        'https://api-vatsubsoil-dev.ggfsystem.com/locations?search=$search&page=$page&limit=$_pageSize');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List locations = data['data']['locations'];
      return List<Map<String, dynamic>>.from(locations);
    } else {
      throw Exception('Gagal mengambil data');
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _pagingController.refresh();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Lokasi"),
      actions: [
        IconButton(icon: Icon(Icons.history),
          onPressed: (){
            Navigator.push(
              context,
               MaterialPageRoute(builder: (_) => const TrackingHistoryPage()));
          },
          )
      ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Cari berdasarkan ID atau Nama',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                
              ),
              onChanged: _onSearch,
            ),
          ),
        
          Expanded(
            child: PagedListView<int, Map<String, dynamic>>(
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
                itemBuilder: (context, item, index) {
                  final name = item['name'] ?? 'Tanpa Nama';
                  final area = item['area'] ?? '-';
                  return ListTile(
                    title: Text("ID: ${item['id']}"),
                    subtitle: Text("Area: $area Ha"),
                    trailing: const Icon(Icons.map_outlined),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GeofencePage(id : item['id'], name: name),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
