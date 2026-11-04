// GENERATED from the SafeAlert mobile DB design (14 tables, 20 foreign keys).
// Each entry is ONE SQL statement: sqflite executes statements one at a time.

const int kSchemaVersion = 1;

const List<String> kSchemaStatements = [
  // [CACHE] LOCAL_PROFILE: ข้อมูลผู้ใช้ที่ล็อกอินอยู่ (มีแถวเดียว)
  '''CREATE TABLE LOCAL_PROFILE (
  user_id TEXT PRIMARY KEY,
  employee_code TEXT NOT NULL,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  emergency_contact TEXT,
  language TEXT NOT NULL,
  ble_enabled INTEGER NOT NULL,
  alert_sound INTEGER NOT NULL,
  updated_at TEXT NOT NULL
)''',
  // [CACHE] FLOOR_MAP: ผังชั้นที่ดาวน์โหลดเก็บไว้ ใช้งานได้แม้ไม่มีเน็ต
  '''CREATE TABLE FLOOR_MAP (
  floor_id TEXT PRIMARY KEY,
  building_name TEXT NOT NULL,
  floor_number INTEGER NOT NULL,
  label TEXT NOT NULL,
  map_version INTEGER NOT NULL,
  map_file_path TEXT NOT NULL,
  width_m REAL NOT NULL,
  height_m REAL NOT NULL,
  downloaded_at TEXT NOT NULL
)''',
  // [CACHE] ZONE_CACHE: โซนในชั้น + สถานะอันตรายล่าสุด ใช้ถ่วงน้ำหนักเส้นทาง
  '''CREATE TABLE ZONE_CACHE (
  zone_id TEXT PRIMARY KEY,
  floor_id TEXT NOT NULL,
  zone_code TEXT UNIQUE NOT NULL,
  zone_name TEXT NOT NULL,
  zone_type TEXT NOT NULL,
  is_evacuation_route INTEGER NOT NULL,
  polygon_json TEXT NOT NULL,
  hazard_level INTEGER NOT NULL,
  hazard_updated_at TEXT,
  FOREIGN KEY (floor_id) REFERENCES FLOOR_MAP(floor_id)
)''',
  // [CACHE] BEACON_CACHE: รายชื่อ beacon และพิกัด ใช้คำนวณตำแหน่ง
  '''CREATE TABLE BEACON_CACHE (
  beacon_uid TEXT PRIMARY KEY,
  floor_id TEXT NOT NULL,
  zone_id TEXT NOT NULL,
  major INTEGER NOT NULL,
  minor INTEGER NOT NULL,
  pos_x REAL NOT NULL,
  pos_y REAL NOT NULL,
  tx_power INTEGER NOT NULL,
  rssi_1m INTEGER NOT NULL,
  path_loss_n REAL NOT NULL,
  is_active INTEGER NOT NULL,
  FOREIGN KEY (floor_id) REFERENCES FLOOR_MAP(floor_id),
  FOREIGN KEY (zone_id) REFERENCES ZONE_CACHE(zone_id)
)''',
  // [CACHE] NAV_NODE: จุดของกราฟนำทาง (ทางแยก ประตู บันได ทางออก)
  '''CREATE TABLE NAV_NODE (
  node_id TEXT PRIMARY KEY,
  floor_id TEXT NOT NULL,
  zone_id TEXT NOT NULL,
  node_type TEXT NOT NULL,
  label TEXT,
  pos_x REAL NOT NULL,
  pos_y REAL NOT NULL,
  is_exit INTEGER NOT NULL,
  exit_priority INTEGER,
  FOREIGN KEY (floor_id) REFERENCES FLOOR_MAP(floor_id),
  FOREIGN KEY (zone_id) REFERENCES ZONE_CACHE(zone_id)
)''',
  // [CACHE] NAV_EDGE: เส้นทางเดินระหว่างจุด พร้อมระยะทาง
  '''CREATE TABLE NAV_EDGE (
  edge_id TEXT PRIMARY KEY,
  from_node TEXT NOT NULL,
  to_node TEXT NOT NULL,
  zone_id TEXT NOT NULL,
  distance_m REAL NOT NULL,
  edge_type TEXT NOT NULL,
  is_bidirectional INTEGER NOT NULL,
  base_factor REAL NOT NULL,
  FOREIGN KEY (from_node) REFERENCES NAV_NODE(node_id),
  FOREIGN KEY (to_node) REFERENCES NAV_NODE(node_id),
  FOREIGN KEY (zone_id) REFERENCES ZONE_CACHE(zone_id)
)''',
  // [CACHE] INCIDENT_CACHE: เหตุการณ์ที่ยังเปิดอยู่ ใช้แสดงผลและคำนวณเส้นทาง
  '''CREATE TABLE INCIDENT_CACHE (
  incident_id TEXT PRIMARY KEY,
  zone_id TEXT NOT NULL,
  incident_type TEXT NOT NULL,
  severity TEXT NOT NULL,
  status TEXT NOT NULL,
  confidence_score REAL,
  detected_at TEXT NOT NULL,
  confirmed_at TEXT,
  resolved_at TEXT,
  server_seq INTEGER NOT NULL,
  FOREIGN KEY (zone_id) REFERENCES ZONE_CACHE(zone_id)
)''',
  // [CACHE] NOTIFICATION_INBOX: กล่องแจ้งเตือนในแอป (หน้า 05)
  '''CREATE TABLE NOTIFICATION_INBOX (
  notification_id TEXT PRIMARY KEY,
  incident_id TEXT,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  priority TEXT NOT NULL,
  received_at TEXT NOT NULL,
  read_at TEXT,
  FOREIGN KEY (incident_id) REFERENCES INCIDENT_CACHE(incident_id)
)''',
  // [OUTBOX] REPORT_OUTBOX: รายงานที่ผู้ใช้ส่ง รอส่งขึ้นเซิร์ฟเวอร์ (ส่งซ้ำได้ไม่ซ้ำข้อมูล)
  '''CREATE TABLE REPORT_OUTBOX (
  client_uuid TEXT PRIMARY KEY,
  server_report_id TEXT UNIQUE,
  zone_id TEXT,
  report_type TEXT NOT NULL,
  severity TEXT NOT NULL,
  description TEXT,
  photo_paths_json TEXT,
  ai_label TEXT,
  ai_confidence REAL,
  pos_x REAL,
  pos_y REAL,
  created_at TEXT NOT NULL,
  sync_status TEXT NOT NULL,
  retry_count INTEGER NOT NULL,
  last_error TEXT,
  synced_at TEXT,
  FOREIGN KEY (zone_id) REFERENCES ZONE_CACHE(zone_id)
)''',
  // [OUTBOX] ACK_OUTBOX: การตอบรับ "ฉันปลอดภัย / ขอความช่วยเหลือ / SOS" รอส่งขึ้น
  '''CREATE TABLE ACK_OUTBOX (
  client_uuid TEXT PRIMARY KEY,
  incident_id TEXT,
  zone_id TEXT,
  ack_status TEXT NOT NULL,
  message TEXT,
  created_at TEXT NOT NULL,
  sync_status TEXT NOT NULL,
  retry_count INTEGER NOT NULL,
  synced_at TEXT,
  FOREIGN KEY (incident_id) REFERENCES INCIDENT_CACHE(incident_id),
  FOREIGN KEY (zone_id) REFERENCES ZONE_CACHE(zone_id)
)''',
  // [LOCAL] LOCATION_FIX: ตำแหน่งที่คำนวณได้ เก็บแค่ 5 นาทีล่าสุด ส่งขึ้นเฉพาะค่าล่าสุด
  '''CREATE TABLE LOCATION_FIX (
  fix_id INTEGER PRIMARY KEY AUTOINCREMENT,
  floor_id TEXT NOT NULL,
  zone_id TEXT NOT NULL,
  edge_id TEXT,
  pos_x REAL NOT NULL,
  pos_y REAL NOT NULL,
  accuracy_m REAL NOT NULL,
  method TEXT NOT NULL,
  beacon_count INTEGER NOT NULL,
  heading_deg REAL,
  measured_at TEXT NOT NULL,
  uploaded INTEGER NOT NULL,
  FOREIGN KEY (floor_id) REFERENCES FLOOR_MAP(floor_id),
  FOREIGN KEY (zone_id) REFERENCES ZONE_CACHE(zone_id),
  FOREIGN KEY (edge_id) REFERENCES NAV_EDGE(edge_id)
)''',
  // [LOCAL] NAV_SESSION: การนำทางแต่ละครั้ง (หน้า 07, 11a–11d)
  '''CREATE TABLE NAV_SESSION (
  session_id TEXT PRIMARY KEY,
  incident_id TEXT,
  start_node TEXT NOT NULL,
  target_node TEXT NOT NULL,
  route_label TEXT NOT NULL,
  route_nodes_json TEXT NOT NULL,
  total_distance_m REAL NOT NULL,
  status TEXT NOT NULL,
  reroute_count INTEGER NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  FOREIGN KEY (incident_id) REFERENCES INCIDENT_CACHE(incident_id),
  FOREIGN KEY (start_node) REFERENCES NAV_NODE(node_id),
  FOREIGN KEY (target_node) REFERENCES NAV_NODE(node_id)
)''',
  // [LOCAL] BLE_CALIBRATION: ค่าที่วัดตอนตั้งค่า beacon (โหมดผู้ดูแล)
  '''CREATE TABLE BLE_CALIBRATION (
  calib_id INTEGER PRIMARY KEY AUTOINCREMENT,
  beacon_uid TEXT NOT NULL,
  rssi_1m_avg REAL NOT NULL,
  path_loss_n REAL NOT NULL,
  sample_count INTEGER NOT NULL,
  device_model TEXT NOT NULL,
  measured_at TEXT NOT NULL,
  FOREIGN KEY (beacon_uid) REFERENCES BEACON_CACHE(beacon_uid)
)''',
  // [LOCAL] SYNC_STATE: จุดที่ซิงก์ล่าสุดของแต่ละข้อมูล
  '''CREATE TABLE SYNC_STATE (
  entity TEXT PRIMARY KEY,
  last_seq INTEGER NOT NULL,
  last_version INTEGER,
  last_sync_at TEXT,
  last_status TEXT
)''',
  // indexes + LOCATION_FIX ring buffer (keep last 300 rows ≈ 5 min at 1 Hz)
  '''CREATE INDEX idx_beacon_major_minor ON BEACON_CACHE(major, minor)''',
  '''CREATE INDEX idx_edge_from ON NAV_EDGE(from_node)''',
  '''CREATE INDEX idx_edge_to ON NAV_EDGE(to_node)''',
  '''CREATE INDEX idx_incident_status ON INCIDENT_CACHE(status)''',
  '''CREATE INDEX idx_report_sync ON REPORT_OUTBOX(sync_status)''',
  '''CREATE INDEX idx_ack_sync ON ACK_OUTBOX(sync_status)''',
  '''CREATE INDEX idx_fix_time ON LOCATION_FIX(measured_at)''',
  '''CREATE INDEX idx_notif_received ON NOTIFICATION_INBOX(received_at)''',
  '''CREATE TRIGGER trg_fix_ring AFTER INSERT ON LOCATION_FIX BEGIN
  DELETE FROM LOCATION_FIX WHERE fix_id <= NEW.fix_id - 300;
END''',
];

/// Tables in delete-safe order (children before parents), used by [AppDatabase.clearCache].
const List<String> kTablesChildFirst = ['NAV_SESSION', 'LOCATION_FIX', 'BLE_CALIBRATION', 'ACK_OUTBOX', 'REPORT_OUTBOX', 'NOTIFICATION_INBOX', 'INCIDENT_CACHE', 'NAV_EDGE', 'NAV_NODE', 'BEACON_CACHE', 'ZONE_CACHE', 'FLOOR_MAP', 'LOCAL_PROFILE', 'SYNC_STATE'];
