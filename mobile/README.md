# SafeAlert ICT · แอปมือถือ (Flutter)

โครงแอปรุ่นแรก ทำงานได้ครบ 1 เส้นทาง: **ล็อกอิน → หาตำแหน่งด้วย BLE → เกิดเหตุ → เลือกเส้นทาง A/B/C → นำทางทีละขั้น → กด "ฉันปลอดภัย"**
หน้าที่ยังไม่ได้เขียนจะขึ้นกล่อง "ยังไม่ได้เขียน" และบอกว่าตรงกับหน้าไหนใน Figma

## เริ่มรันครั้งแรก

ต้องมี Flutter 3.22 ขึ้นไป (`flutter --version`)

```bash
cd safealert_app
flutter create --org th.ac.mahidol.ict --project-name safealert --platforms android,ios .
# ↑ สร้างโฟลเดอร์ android/ กับ ios/ ให้ โดยไม่ทับไฟล์ที่มีอยู่แล้ว
rm test/widget_test.dart   # ไฟล์ตัวอย่างที่ flutter create แถมมา (อ้าง MyApp ที่ไม่มี) ลบทิ้ง
flutter pub get
flutter test          # ต้องผ่านทั้ง 3 ไฟล์ (navigation, positioning, database)
flutter run
```

จากนั้นใส่สิทธิ์ BLE ตาม [docs/platform_setup.md](docs/platform_setup.md)

> เวอร์ชันแพ็กเกจใน `pubspec.yaml` ตั้งตามที่รู้ล่าสุด ถ้า `flutter pub get` ฟ้องว่าเวอร์ชันชนกัน ให้รัน
> `flutter pub upgrade --major-versions` แล้วรัน `flutter test` อีกครั้ง

## ลองเดโมโดยไม่มี beacon

`lib/core/config.dart` → `useSimulatedBeacons = true` (ค่าเริ่มต้น) แอปจะจำลองคนเดินจากหน้า Lab 212 ไปหน้าห้อง 201
แล้วสร้างสัญญาณ beacon ปลอมให้ (มีสัญญาณรบกวน ±4 dB เหมือนของจริง)

1. ล็อกอิน เลือกบทบาทไหนก็ได้ (เลือก "ผู้ดูแลอาคาร" จะเห็นส่วนของ admin ในหน้าหลัก)
2. หน้าหลักจะเห็นตำแหน่งปัจจุบันเปลี่ยนทุกวินาที
3. กด **จำลองเหตุไฟไหม้ห้อง 203** → แอปไปหน้าแผนที่ เห็นห้อง 203 สีแดง โถงหน้าห้องสีเหลือง (ควัน) และเส้นทาง A/B (ลิฟต์ขึ้นว่าห้ามใช้)
4. กด **นำทางตามเส้นทาง A** → คนจำลองเดินตามเส้นทาง แถบด้านบนเปลี่ยนคำสั่งเอง
5. ถึงทางออก → กด **ฉันปลอดภัย** → ลงตาราง ACK_OUTBOX แล้วพยายามส่งขึ้นเซิร์ฟเวอร์

ใช้ beacon จริง: ตั้ง `useSimulatedBeacons = false` แล้วรันบนมือถือ Android จริง (emulator ไม่มีบลูทูธ)

## โค้ดอยู่ไหน · ตรงกับงานออกแบบตรงไหน

| ไฟล์ | ทำอะไร | ตรงกับงานออกแบบ |
|---|---|---|
| `lib/data/db/schema.dart` | สร้าง 14 ตาราง + index + trigger เก็บตำแหน่ง 300 แถว | `mobile_schema.sql`, ER มือถือ |
| `lib/data/db/app_database.dart` | เปิดไฟล์ `safealert.db` ในเครื่อง · นำเข้าผังชั้น | FLOOR_MAP, ZONE_CACHE, BEACON_CACHE, NAV_NODE, NAV_EDGE |
| `lib/data/repositories/map_repository.dart` | อ่านผังชั้นจาก DB · บันทึกตำแหน่ง · ตั้งระดับอันตราย | LOCATION_FIX, ZONE_CACHE.hazard_level |
| `lib/data/repositories/outbox_repository.dart` | รายงาน / ตอบรับ / SOS ที่รอส่ง (มี client_uuid) | REPORT_OUTBOX, ACK_OUTBOX |
| `lib/ble/ibeacon.dart` | แกะข้อมูล iBeacon จากสัญญาณ BLE | UUID / major / minor |
| `lib/ble/beacon_scanner.dart` | ตัวสแกนจริง (Android) + ตัวจำลอง | BLE Scanner ในแผนภาพสถาปัตยกรรม |
| `lib/positioning/positioning_engine.dart` | Kalman → 3 ตัวแรงสุด → Weighted Centroid → snap → โซน | Positioning Engine |
| `lib/navigation/route_planner.dart` | Dijkstra ถ่วงน้ำหนักอันตราย · คำสั่งเลี้ยว · ตรวจหลุดเส้นทาง | Navigation Engine |
| `lib/sync/sync_service.dart` | ส่ง outbox (SOS ก่อน) · ดึงเหตุตาม seq · ส่งตำแหน่งล่าสุด | Sync Service + REST API |
| `lib/app_state.dart` | เชื่อมทุกส่วนเข้าด้วยกัน · โหมดปกติ / เกิดเหตุ / นำทาง | โหมดการทำงาน 3 แบบ |
| `lib/features/` | หน้าจอ: ล็อกอิน (01), หน้าหลัก (02 / ad02), แผนที่ + นำทาง (03, 07, 11) | Figma |
| `assets/maps/floor2.json` | ผังชั้น 2 ตัวอย่าง: 14 โซน · 10 beacon · 18 จุด · 17 เส้น | data dictionary ชีต Beacons / Nav |

## ยังไม่ได้ทำ (เรียงตามที่ควรทำต่อ)

- [ ] วัดผังชั้น 2 จริง แล้วแก้ `assets/maps/floor2.json`
- [ ] เขียนฝั่งเซิร์ฟเวอร์ตาม API ที่เขียนไว้บนหัวไฟล์ `sync_service.dart`
- [ ] ล็อกอินจริง (POST /auth/login) และเก็บ token ใน `flutter_secure_storage`
- [ ] ขอสิทธิ์ BLE ตอนเปิดแอป (`permission_handler`) และเปิด foreground service ตอนเกิดเหตุ
- [ ] รับ push (FCM) / WebSocket แล้วเรียก `AppState.onIncident(...)`
- [ ] หน้า 04 แจ้งเหตุ, 05 แจ้งเตือน, 08 โปรไฟล์ และหน้าของ admin (ad03–ad14)
- [ ] ตัวสแกนสำหรับ iOS (CoreLocation ranging) — ดู docs/platform_setup.md
- [ ] หน้า calibrate beacon สำหรับ admin → BLE_CALIBRATION
