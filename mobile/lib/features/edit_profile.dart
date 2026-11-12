import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../main.dart';

/// Page 08b: แก้ไขโปรไฟล์. Grey fields come from the university system and cannot be changed.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone, _contactName, _contactPhone;
  bool _saving = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final s = AppScope.of(context);
    // emergency_contact is stored as "name · phone"
    final parts = (s.emergencyContact ?? '').split(' · ');
    _name = TextEditingController(text: s.displayName);
    _phone = TextEditingController(text: s.phone ?? '');
    _contactName =
        TextEditingController(text: parts.isNotEmpty ? parts.first : '');
    _contactPhone =
        TextEditingController(text: parts.length > 1 ? parts[1] : '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tr;
    final roleLabel = switch (s.role) {
      UserRole.student => t('นักศึกษา', 'Student'),
      UserRole.security => t('เจ้าหน้าที่', 'Staff'),
      UserRole.admin => t('ผู้ดูแลระบบ', 'Administrator'),
    };

    return Scaffold(
      backgroundColor: SA.bg,
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // ---------------------------------------------------------------- top bar
              Row(children: [
                Material(
                  color: SA.card,
                  shape: const CircleBorder(side: BorderSide(color: SA.border)),
                  child: IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => Navigator.pop(context)),
                ),
                Expanded(
                  child: Text(
                    t('แก้ไขโปรไฟล์', 'Edit profile'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(
                    width:
                        48), // balances the back button so the title stays centred
              ]),
              const SizedBox(height: 16),

              // ---------------------------------------------------------------- avatar
              Center(
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: SA.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: SA.border, width: 2)),
                    child: Text(
                      _name.text.isEmpty ? '?' : _name.text.characters.first,
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: SA.navy),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Material(
                      color: SA.teal,
                      shape: const CircleBorder(
                          side: BorderSide(color: Colors.white, width: 2)),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(t(
                                  'เปลี่ยนรูปโปรไฟล์ ยังไม่ได้เขียน',
                                  'Changing the photo is not built yet'))),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.photo_camera_outlined,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              // ---------------------------------------------------------------- personal
              _heading(t('ข้อมูลส่วนตัว', 'Personal info')),
              _label(t('ชื่อ-นามสกุล', 'Full name')),
              _field(
                _name,
                hint: t('ชื่อ นามสกุล', 'First and last name'),
                onChanged: (_) =>
                    setState(() {}), // avatar letter follows the name
                validator: (v) => (v ?? '').trim().isEmpty
                    ? t('กรุณากรอกชื่อ', 'Please enter your name')
                    : null,
              ),
              _label(t('อีเมลมหาวิทยาลัย', 'University email')),
              _locked(s.email.isEmpty ? '-' : s.email),
              _label(t('รหัสนักศึกษา / บทบาท', 'Student ID / role')),
              _locked(
                  '${s.employeeCode.isEmpty ? '-' : s.employeeCode} · $roleLabel'),
              _label(t('เบอร์ของฉัน', 'My phone')),
              _field(_phone,
                  hint: '08x-xxx-xxxx',
                  phone: true,
                  validator: (v) => _phoneError(v, s)),
              const SizedBox(height: 12),

              // ---------------------------------------------------------------- emergency contact
              _heading(t('ผู้ติดต่อฉุกเฉิน', 'Emergency contact')),
              _label(t('ชื่อผู้ติดต่อ', 'Contact name')),
              _field(_contactName,
                  hint: t('เช่น ชื่อผู้ปกครอง', 'e.g. a parent’s name')),
              _label(t('เบอร์ผู้ติดต่อ', 'Contact phone')),
              _field(_contactPhone,
                  hint: '08x-xxx-xxxx',
                  phone: true,
                  validator: (v) => _phoneError(v, s)),
              const SizedBox(height: 10),
              Text(
                t('ช่องสีเทาแก้ไขไม่ได้ ดึงจากระบบมหาวิทยาลัย',
                    'Grey fields cannot be edited; they come from the university system'),
                style: const TextStyle(color: SA.muted, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // ---------------------------------------------------------------- save
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: SA.teal,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : () => _save(s),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(t('บันทึกการเปลี่ยนแปลง', 'Save changes'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- pieces
  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: SA.text2, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  Widget _field(
    TextEditingController c, {
    required String hint,
    bool phone = false,
    ValueChanged<String>? onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: phone ? TextInputType.phone : TextInputType.name,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: SA.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SA.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SA.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SA.teal, width: 1.5)),
      ),
    );
  }

  Widget _locked(String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
            color: const Color(0xFFE9EDF3),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
              child: Text(value,
                  style: const TextStyle(color: SA.muted),
                  overflow: TextOverflow.ellipsis)),
          const Icon(Icons.lock, color: SA.muted, size: 18),
        ]),
      );

  /// Empty is fine; otherwise 9–10 digits (dashes and spaces allowed).
  String? _phoneError(String? v, AppState s) {
    final digits = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (digits.isEmpty) return null;
    if (!RegExp(r'^\d{9,10}$').hasMatch(digits))
      return s.tr('เบอร์โทรไม่ถูกต้อง', 'Invalid phone number');
    return null;
  }

  Future<void> _save(AppState s) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await s.updateProfile(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      contactName: _contactName.text.trim(),
      contactPhone: _contactPhone.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.tr('บันทึกแล้ว', 'Saved'))));
    Navigator.pop(context);
  }
}
