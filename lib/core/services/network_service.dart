import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static Future<bool> get isConnected async {
    var result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}