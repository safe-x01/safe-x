/// App-wide settings. Change these here, not inside the features.
class AppConfig {
  AppConfig._();

  /// One iBeacon UUID for the whole project. major = floor, minor = beacon 1..10.
  static const String projectUuid = '44BC8758-5427-4729-B840-3AEA56C2B4FB';

  /// Edge Server inside the building (change to the real address).
  static const String serverBaseUrl = 'http://192.168.1.10:8000';

  /// true = use the simulated scanner so the app runs on an emulator with no beacons.
  static const bool useSimulatedBeacons = true;

  /// Floor package bundled with the app for the first start.
  static const String bundledFloorAsset = 'assets/maps/floor2.json';

  // ---- BLE / positioning ----
  static const Duration scanWindow = Duration(seconds: 1);
  static const int minRssi = -95; // weaker frames are dropped
  static const double hysteresisDb = 4; // a new strongest beacon must win by 4 dB ...
  static const int hysteresisWindows = 2; // ... for 2 windows in a row
  static const double maxWalkSpeedMps = 2.0; // faster jumps are rejected
  static const double doorSnapPenaltyM = 1.5; // prefer corridor edges when snapping
  static const int zoneVoteWindows = 3;

  // ---- navigation ----
  static const double offRouteMeters = 4;
  static const Duration offRouteFor = Duration(seconds: 3);
  static const double arriveMeters = 3;
  static const double turnThresholdDeg = 30;

  // ---- upload ----
  static const Duration locationUploadInIncident = Duration(seconds: 5);
  static const int maxRetryBackoffSec = 60;
}
