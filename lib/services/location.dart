import 'package:location/location.dart';


class LocationService {
  final Location _locService = Location();
  bool _serviceEnabled=false;
  PermissionStatus? _permissionGranted;

  Future<LocationData> updateLocation() async {
    LocationData locationData = await _locService.getLocation();
    return locationData;
  }

  void init() async {
    _serviceEnabled = await _locService.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locService.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await _locService.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locService.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
    updateLocation();

 }

}