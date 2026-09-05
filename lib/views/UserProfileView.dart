import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key});

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  // بنفتح أو بنشئ صندوق خاص ببيانات المستخدم في Hive
  late Box userBox;
  bool _isEditing = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    userBox = Hive.box('favorites'); // أو ممكن نعمل صندوق منفصل مثل 'user_box' لو حابة
    _loadUserData();
  }

  void _loadUserData() {
    // بنجيب البيانات القديمة لو متخزنة، أو بنحط قيم افتراضية
    _nameController.text = userBox.get('user_name', defaultValue: 'ندا فيصل');
    _emailController.text = userBox.get('user_email', defaultValue: 'nada@bookii.com');
  }

  void _saveUserData() {
    userBox.put('user_name', _nameController.text);
    userBox.put('user_email', _emailController.text);
    setState(() {
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ البيانات بنجاح 🌟')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text(
          'حسابي',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveUserData();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // صورة البروفايل مع أيقونة تعديل خفيفة
            Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // بطاقة المعلومات الشخصية
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المعلومات الشخصية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Divider(height: 24),

                  // حقل الاسم
                  _buildTextField(
                    label: 'الاسم الكامل',
                    controller: _nameController,
                    icon: Icons.person_outline,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 16),

                  // حقل البريد الإلكتروني
                  _buildTextField(
                    label: 'البريد الإلكتروني',
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    enabled: _isEditing,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // بطاقة إحصائيات سريعة مرتبطة بـ Hive (عدد الكتب المفضلة مثلاً)
            ValueListenableBuilder(
              valueListenable: userBox.listenable(),
              builder: (context, Box box, _) {
                // بنحسب عدد الكتب المفضلة المخزنة تلقائياً
                int favCount = box.keys.where((key) => key.toString() != 'user_name' && key.toString() != 'user_email').length;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('الكتب المفضلة', '$favCount'),
                      Container(height: 30, width: 1, color: Colors.grey[300]),
                      _buildStatItem('التطبيق', 'Bookii'),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
            filled: true,
            fillColor: enabled ? const Color(0xFFF7F7FA) : Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C63FF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }
}