/// iBeacon frame inside BLE manufacturer data (Apple company id 0x004C):
/// [0x02, 0x15, 16-byte UUID, major (2), minor (2), measured power (1, signed)].
class IBeaconFrame {
  final String uuid;
  final int major, minor, measuredPower;
  const IBeaconFrame(this.uuid, this.major, this.minor, this.measuredPower);

  /// Same format as BEACON_CACHE.beacon_uid.
  String get uid => '$uuid-$major-$minor';
}

const int kAppleCompanyId = 0x004C;

/// Returns null when the data is not an iBeacon frame.
IBeaconFrame? parseIBeacon(Map<int, List<int>> manufacturerData) {
  final d = manufacturerData[kAppleCompanyId];
  if (d == null || d.length < 23) return null;
  if (d[0] != 0x02 || d[1] != 0x15) return null;
  final hex = d.sublist(2, 18).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  final uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
  final major = (d[18] << 8) | d[19];
  final minor = (d[20] << 8) | d[21];
  final power = d[22] > 127 ? d[22] - 256 : d[22];
  return IBeaconFrame(uuid, major, minor, power);
}
