import 'package:flutter/foundation.dart';
import 'package:romanticists_app/services/collections_service.dart';

enum CollectionsStatus { initial, loading, loaded, failure }

class CollectionsProvider with ChangeNotifier {
  List<PostCollection> _items = [];
  CollectionsStatus _status = CollectionsStatus.initial;
  String? _errorMessage;

  List<PostCollection> get items => _items;
  CollectionsStatus get status => _status;
  String? get errorMessage => _errorMessage;

  Future<void> load(String uid) async {
    _status = CollectionsStatus.loading;
    notifyListeners();

    try {
      // CollectionsService already handles SWR-like logic (cache first then fresh)
      // but it returns a Future. We'll call it to get the freshest data.
      final results = await CollectionsService.instance.getCollections(uid);
      _items = results;
      _status = CollectionsStatus.loaded;
      _errorMessage = null;
    } catch (e) {
      _status = CollectionsStatus.failure;
      _errorMessage = 'Failed to load collections';
    } finally {
      notifyListeners();
    }
  }

  void clear() {
    _items = [];
    _status = CollectionsStatus.initial;
    notifyListeners();
  }
}
