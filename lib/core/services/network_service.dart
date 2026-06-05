import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static Future<bool> get isConnected async {
    var result = await Connectivity().checkConnectivity();
    // Como el dispositivo puede tener varias conexiones a la vez (wifi + datos), 
    // revisamos que al menos una no sea "sin conexión"
    return !result.contains(ConnectivityResult.none);
  }
}