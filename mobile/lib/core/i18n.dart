/// English for text that comes from DATA (floor map, notifications, sensors),
/// not from the screens. Screen text uses AppState.tr('ไทย', 'English') instead.
///
/// [translateData] first looks for the whole text, then replaces every known
/// piece inside it (longest first), so "ตรวจพบไฟไหม้ ห้อง 203" -> "Fire detected Room 203".
/// Text it does not know stays in Thai.
const Map<String, String> kEnglish = {
  // ---- zones (assets/maps/floor2.json)
  'โถงกลาง ฝั่งตะวันตก': 'Corridor (west)',
  'โถงกลาง หน้าห้อง 203': 'Corridor by Room 203',
  'โถงกลาง หน้าห้อง 201': 'Corridor by Room 201',
  'โถงกลาง ฝั่งตะวันออก': 'Corridor (east)',
  'โถงกลาง': 'Corridor',
  'บันได W': 'Stairs W',
  'บันได E': 'Stairs E',
  'ห้องพักอาจารย์': 'Lecturers’ room',
  'ห้องน้ำ': 'Restroom',
  'ลิฟต์': 'Lift',
  'ห้อง': 'Room',
  // ---- nav nodes
  'บันไดหนีไฟ W': 'Fire exit W',
  'บันไดหนีไฟ E': 'Fire exit E',
  'โถงหน้าบันได W': 'corridor by stairs W',
  'โถงหน้าบันได E': 'corridor by stairs E',
  'โถงหน้า Lab 212': 'corridor by Lab 212',
  'โถงหน้าห้อง 203': 'corridor by Room 203',
  'โถงหน้าห้อง 204': 'corridor by Room 204',
  'โถงหน้าห้อง 201': 'corridor by Room 201',
  'หน้าลิฟต์': 'lift lobby',
  'หน้าห้องน้ำ': 'by the restroom',
  'ประตูห้องพักอาจารย์': 'Lecturers’ room door',
  'ประตูห้อง': 'door of Room',
  'ประตู': 'door of',
  'ทางออก': 'Exit',
  'ชั้น': 'Floor',
  // ---- notifications (demo + incident)
  'ตรวจพบไฟไหม้': 'Fire detected',
  'ตรวจพบแก๊สรั่ว': 'Gas leak detected',
  'แผ่นดินไหว': 'Earthquake',
  'อาคาร ICT · ออกทางบันไดหนีไฟ ห้ามใช้ลิฟต์':
      'ICT Building · use the fire stairs, do not use the lift',
  'ยืนยันโดย MQ-2 และกล้อง AI': 'Confirmed by MQ-2 and AI camera',
  'ตรวจพบคนล้ม': 'Person fall detected',
  'โถงกลาง ชั้น 2 จากกล้อง AI': 'Floor 2 corridor, from AI camera',
  'เจ้าหน้าที่กำลังเข้าช่วยเหลือ': 'Staff are on the way',
  'ความมั่นใจ 91% นิ่งนาน 6 วินาที': 'Confidence 91% · still for 6 seconds',
  'ลิฟต์งดใช้งานชั่วคราว': 'Lift temporarily closed',
  'ระหว่างเหตุฉุกเฉิน กรุณาใช้บันไดหนีไฟ':
      'During the emergency, please use the fire stairs',
  'ดูรายละเอียด': 'View details',
  'รายงานของคุณได้รับการยืนยัน': 'Your report was confirmed',
  'น้ำรั่วที่ห้องน้ำ ชั้น 2 ซ่อมเสร็จแล้ว':
      'Water leak in the floor 2 restroom has been fixed',
  'ขอบคุณที่ช่วยให้ทุกคนปลอดภัย': 'Thank you for helping keep everyone safe',
  'ส่งเข้า Telegram แล้ว': 'Sent to Telegram',
  'กลุ่ม ICT Safety ถึง 128 คน ใน 318 ms':
      'ICT Safety group · 128 people in 318 ms',
};

final List<MapEntry<String, String>> _byLength = kEnglish.entries.toList()
  ..sort((a, b) => b.key.length.compareTo(a.key.length));

String translateData(String th) {
  final whole = kEnglish[th];
  if (whole != null) return whole;
  var out = th;
  for (final e in _byLength) {
    if (out.contains(e.key)) out = out.replaceAll(e.key, e.value);
  }
  return out;
}
