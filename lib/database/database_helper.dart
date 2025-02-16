import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:intl/intl.dart'; // مكتبة للتعامل مع التاريخ
import 'package:googleapis/drive/v3.dart' as drive;
// import 'package:googleapis/drive/v3.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ================================
// import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

// import 'package:intl/intl.dart';
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

// ============================================
//           ادارة قاعدة البيانات
// ============================================
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');
// حذف قاعدة البيانات إذا كانت موجودة (للتطوير فقط)
    // await deleteDatabase(path);
    return await openDatabase(
      path,
      version: 6, // زيادة رقم الإصدار لأننا أضفنا جداول جديدة
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade,
    );
  }

//  انشاء الجدوال
  Future<void> _onCreate(Database db, int version) async {
    // إنشاء جدول العملاء
    await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL
    )
  ''');

    // إنشاء جدول العمليات للعملاء
    await db.execute('''
    CREATE TABLE operations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL,
      amount REAL,
      details TEXT,
      type TEXT,
      date TEXT,
      FOREIGN KEY (client_id) REFERENCES customers (id)
    )
  ''');

    // إنشاء جدول الحساب اليومي
    await db.execute('''
    CREATE TABLE daily_account (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      details TEXT NOT NULL,
      type TEXT NOT NULL,
      date TEXT NOT NULL
    )
  ''');

    // إنشاء جدول الوكلاء
    await db.execute('''
    CREATE TABLE agents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL
    )
  ''');

    // إنشاء جدول عمليات الوكلاء
    await db.execute('''
    CREATE TABLE agent_operations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agent_id INTEGER NOT NULL,
      amount REAL,
      details TEXT,
      type TEXT,
      date TEXT,
      FOREIGN KEY (agent_id) REFERENCES agents (id)
    )
  ''');

    await db.execute('''
      CREATE TABLE personal_info(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        serviceType TEXT,
        address TEXT,
        phoneNumber TEXT
      )
    ''');
  }

  // Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < 2) {
  //     // إضافة جدول البيانات الشخصية
  //     await db.execute('''
  //     CREATE TABLE personal_info (
  //       id INTEGER PRIMARY KEY AUTOINCREMENT,
  //       name TEXT,
  //       serviceType TEXT,
  //       address TEXT,
  //       phoneNumber TEXT
  //     )
  //   ''');
  //   }
  // }
/*   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      // إنشاء جدول البيانات الشخصية
      await db.execute('''
      CREATE TABLE personal_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        serviceType TEXT,
        address TEXT,
        phoneNumber TEXT
      )
    ''');

      // إضافة قيم افتراضية
      await db.insert('personal_info', {
        'name': 'اسم افتراضي',
        'serviceType': 'نوع الخدمة الافتراضي',
        'address': 'عنوان افتراضي',
        'phoneNumber': 'رقم الهاتف الافتراضي',
      });
    }
  } */

  // دالة للتحقق من وجود جدول
  Future<bool> doesTableExist(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'",
    );
    return result.isNotEmpty;
  }

  // إضافة أو تحديث البيانات الشخصية
  Future<void> insertOrUpdatePersonalInfo(Map<String, dynamic> info) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM personal_info'),
    );

    if (count == 0) {
      await db.insert('personal_info', info);
    } else {
      await db.update('personal_info', info, where: 'id = 1');
    }
  }

  // جلب البيانات الشخصية
  Future<Map<String, dynamic>?> getPersonalInfo() async {
    final db = await database;
    final result = await db.query('personal_info', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }
// ================================================================
//               ادارة العملاء والتجار
// ================================================================

/* ==================================
   ============== العملاء ============
   ==================================*/
  // إضافة عميل جديد
  Future<int> insertCustomer(String name, String phone) async {
    final db = await database;

    // إزالة الفراغات من بداية ونهاية الاسم
    String trimmedName = name.trim();

    return await db.insert('customers', {'name': trimmedName, 'phone': phone});
  }

  // استرجاع جميع العملاء
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query('customers');
  }

  // تحديث بيانات عميل
  Future<int> updateCustomer(int id, String name, String phone) async {
    final db = await database;
    String trimmedName = name.trim();

    return await db.update(
      'customers',
      {'name': trimmedName, 'phone': phone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // حذف عميل
  Future<int> deleteCustomer(int id) async {
    final db = await database;

    // حذف جميع العمليات المرتبطة بالعميل
    await db.delete(
      'operations',
      where: 'client_id = ?',
      whereArgs: [id],
    );

    // حذف العميل
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// ==============   ملخص كل عمليات العملاء    ================
  Future<Map<String, dynamic>> getTotalSummary() async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "إضافة" لجميع العملاء
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM operations o
    WHERE o.type = "إضافة"
    ''',
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد" لجميع العملاء
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM operations o
    WHERE o.type = "تسديد"
    ''',
    );

    // استعلام للحصول على عدد العملاء
    final customersCountResult = await db.rawQuery(
      '''
    SELECT COUNT(*) as totalCustomers
    FROM customers
    ''',
    );

    // استخراج القيم من النتائج
    final totalAdditions =
        additionsResult.first['totalAdditions'] as double? ?? 0.0;
    final totalPayments =
        paymentsResult.first['totalPayments'] as double? ?? 0.0;
    final totalCustomers =
        customersCountResult.first['totalCustomers'] as int? ?? 0;

    // حساب المبلغ المستحق الكلي
    final totalOutstanding = totalAdditions - totalPayments;

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'totalOutstanding': totalOutstanding,
      'totalCustomers': totalCustomers,
    };
  }

/* ==================================
   ============== الوكلاء ============
   ==================================*/
// إضافة وكيل جديد
  Future<int> insertAgent(String name, String phone) async {
    final db = await database;

    // إزالة الفراغات من بداية ونهاية الاسم
    String trimmedName = name.trim();

    return await db.insert('agents', {'name': trimmedName, 'phone': phone});
  }

  // استرجاع جميع الوكلاء
  Future<List<Map<String, dynamic>>> getAllAgents() async {
    final db = await database;
    return await db.query('agents');
  }

  // حذف وكيل
  Future<int> deleteAgent(int id) async {
    final db = await database;

    // حذف جميع العمليات المرتبطة بالوكيل
    await db.delete(
      'agent_operations',
      where: 'agent_id = ?',
      whereArgs: [id],
    );

    // حذف الوكيل
    return await db.delete(
      'agents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // تعديل وكيل
  Future<int> updateAgent(int id, String name, String phone) async {
    final db = await database;
    return await db.update(
      'agents',
      {'name': name, 'phone': phone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// ==============   ملخص كل عمليات الوكلاء    ================
  Future<Map<String, dynamic>> getTotalAgeensSummary() async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "قرض" لجميع الوكلاء
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM agent_operations o
    WHERE o.type = "قرض"
    ''',
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد" لجميع الوكلاء
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM agent_operations o
    WHERE o.type = "تسديد"
    ''',
    );

    // استعلام للحصول على عدد الوكلاء
    final customersCountResult = await db.rawQuery(
      '''
    SELECT COUNT(*) as totalCustomers
    FROM agents
    ''',
    );

    // استخراج القيم من النتائج
    final totalAdditions =
        additionsResult.first['totalAdditions'] as double? ?? 0.0;
    final totalPayments =
        paymentsResult.first['totalPayments'] as double? ?? 0.0;
    final totalCustomers =
        customersCountResult.first['totalCustomers'] as int? ?? 0;

    // حساب المبلغ المستحق الكلي
    final totalOutstanding = totalAdditions - totalPayments;

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'totalOutstanding': totalOutstanding,
      'totalCustomers': totalCustomers,
    };
  }

/* ===============================================
   ============== اضافة عملية====================
   ===============================================*/

/* ==================================
   ============== العملاء ============
   ==================================*/
  //==========  التحقق من وجود العميل=========
  Future<bool> doesClientExist(String name) async {
    final db = await database;
    final result = await db.query(
      'customers',
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.isNotEmpty;
  }

//  =============  بحث الاسماء المطابقة لما يكتب في الحقل ==============
  Future<List<String>> getClientNames(String query) async {
    final db = await database;

    // البحث عن الأسماء التي تحتوي على النص المدخل
    final result = await db.rawQuery(
      "SELECT name FROM customers WHERE name LIKE ?",
      ['%$query%'],
    );

    // تحويل النتائج إلى قائمة من النصوص
    return result.map((row) => row['name'].toString()).toList();
  }

// =============== ارجاع الاسماء المطابقه للعملاء=============
  Future<List<Map<String, dynamic>>> searchClientsByName(String query) async {
    final db = await database;
    return await db.query(
      'customers',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: 10, // تحديد عدد النتائج
    );
  }

// ============   اضافة عمليه لعميل ===========
  Future<void> insertOperation(
      int clientId, double amount, String details, String type) async {
    final db = await database;
    String creetDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    await db.insert('operations', {
      'client_id': clientId, // حفظ ID العميل
      'amount': amount,
      'details': details,
      'type': type,
      'date': creetDate,
    });
  }

// ===============ارجاع العمليات وعرضها للعملاء======================
  Future<List<Map<String, dynamic>>> getOperationsByDate(DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return await db.rawQuery('''
    SELECT 
      operations.id AS operation_id, 
      operations.client_id, 
      operations.amount, 
      operations.details, 
      operations.type, 
      operations.date,
      customers.name AS client_name
    FROM operations
    LEFT JOIN customers ON operations.client_id = customers.id
    WHERE DATE(operations.date) = ?
    ORDER BY operations.id DESC
  ''', [formattedDate]);
  }

// ===================حذف عملية لعميل ==================
  Future<int> deleteOperation(int operationId) async {
    final db = await database;
    return await db.delete(
      'operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

// ===================تعديل  عملية  لعميل==================
  Future<int> updateOperation(
      int id, double amount, String details, String type) async {
    final db = await database;
    return await db.update(
      'operations',
      {
        'amount': amount,
        'details': details,
        'type': type,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

//===========  ملخص العمليات للعملاء =========
  Future<Map<String, double>> getSummaryByDate(DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // جلب إجمالي التسديدات
    final totalPaymentsResult = await db.rawQuery('''
    SELECT SUM(amount) AS total_payments
    FROM operations
    WHERE DATE(date) = ? AND type = 'تسديد'
  ''', [formattedDate]);

    // جلب إجمالي الإضافات
    final totalAdditionsResult = await db.rawQuery('''
    SELECT SUM(amount) AS total_additions
    FROM operations
    WHERE DATE(date) = ? AND type = 'إضافة'
  ''', [formattedDate]);

    // تحويل القيم إلى double مع التعامل مع القيم الفارغة
    final double totalPayments =
        (totalPaymentsResult.first['total_payments'] as num?)?.toDouble() ??
            0.0;
    final double totalAdditions =
        (totalAdditionsResult.first['total_additions'] as num?)?.toDouble() ??
            0.0;

    return {
      'total_payments': totalPayments,
      'total_additions': totalAdditions,
      'balance': totalPayments - totalAdditions,
    };
  }

/* ==================================
   ============== الوكلاء ============
   ==================================*/
// ============ البحث عن أسماء الوكلاء المتطابقة ==============
  Future<List<String>> getAgentNames(String query) async {
    final db = await database;

    // البحث عن الأسماء التي تحتوي على النص المدخل
    final result = await db.rawQuery(
      "SELECT name FROM agents WHERE name LIKE ?",
      ['%$query%'],
    );

    // تحويل النتائج إلى قائمة من النصوص
    return result.map((row) => row['name'].toString()).toList();
  }

// ============ إرجاع أسماء الوكلاء المتطابقة ===============
  Future<List<Map<String, dynamic>>> searchAgentsByName(String query) async {
    final db = await database;
    return await db.query(
      'agents',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: 10, // تحديد عدد النتائج
    );
  }

// ============ إضافة عملية لوكيل ===============
  Future<void> insertAgentOperation(
      int agentId, double amount, String details, String type) async {
    final db = await database;
    String currentDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    await db.insert('agent_operations', {
      'agent_id': agentId, // حفظ ID الوكيل
      'amount': amount,
      'details': details,
      'type': type,
      'date': currentDate,
    });
  }

// ===============ارجاع العمليات وعرضها للوكلاء======================
  Future<List<Map<String, dynamic>>> getAgentOperationsByDate(
      DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return await db.rawQuery('''
  SELECT 
    agent_operations.id AS operation_id, 
    agent_operations.agent_id, 
    agent_operations.amount, 
    agent_operations.details, 
    agent_operations.type, 
    agent_operations.date,
    agents.name AS agent_name
  FROM agent_operations
  LEFT JOIN agents ON agent_operations.agent_id = agents.id
  WHERE DATE(agent_operations.date) = ?
  ORDER BY agent_operations.id DESC
  ''', [formattedDate]);
  }

// ===================حذف عملية لوكيل ==================
  Future<int> deleteAgentOperation(int operationId) async {
    final db = await database;
    return await db.delete(
      'agent_operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

// ===================تعديل  عملية  لوكيل==================
  Future<int> updateAgentOperation(
      int id, double amount, String details, String type) async {
    final db = await database;

    // تحديث البيانات
    return await db.update(
      'agent_operations',
      {
        'amount': amount,
        'details': details,
        'type': type,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

//===========  ملخص العمليات للوكلاء =========
  Future<Map<String, double>> getAgentSummaryByDate(DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // جلب إجمالي التسديدات
    final totalPaymentsResult = await db.rawQuery('''
  SELECT SUM(amount) AS total_payments
  FROM agent_operations
  WHERE DATE(date) = ? AND type = 'تسديد'
  ''', [formattedDate]);

    // جلب إجمالي الإضافات
    final totalAdditionsResult = await db.rawQuery('''
  SELECT SUM(amount) AS total_additions
  FROM agent_operations
  WHERE DATE(date) = ? AND type = 'قرض'
  ''', [formattedDate]);

    // تحويل القيم إلى double مع التعامل مع القيم الفارغة
    final double totalPayments =
        (totalPaymentsResult.first['total_payments'] as num?)?.toDouble() ??
            0.0;
    final double totalAdditions =
        (totalAdditionsResult.first['total_additions'] as num?)?.toDouble() ??
            0.0;

    return {
      'total_payments': totalPayments,
      'total_additions': totalAdditions,
      'balance': totalPayments - totalAdditions,
    };
  }

/* ===============================================
   ============== بحث عن كشف عميل ===============
   ===============================================*/

  //  ============= بحث عن عميل ===============
  Future<List<Map<String, dynamic>>> getOperationsByClientName(
      String name) async {
    final db = await database;

    // استعلام لاسترجاع العمليات المرتبطة باسم العميل المدخل
    return await db.rawQuery('''
    SELECT 
      operations.id AS operation_id, 
      operations.amount, 
      operations.details, 
      operations.type, 
      operations.date, 
      customers.name AS client_name
    FROM operations
    INNER JOIN customers ON operations.client_id = customers.id
    WHERE customers.name = ?
    ORDER BY operations.date DESC
  ''', [name]);
  }

  //  ============= بحث عن وكيل ===============
  Future<List<Map<String, dynamic>>> getOperationsByAgenntName(
      String name) async {
    final db = await database;

    // استعلام لاسترجاع العمليات المرتبطة باسم العميل المدخل
    return await db.rawQuery('''
    SELECT 
      agent_operations.id AS agent_id, 
      agent_operations.amount, 
      agent_operations.details, 
      agent_operations.type, 
      agent_operations.date, 
      agents.name AS agent_id
    FROM agent_operations
    INNER JOIN agents ON agent_operations.agent_id = agents.id
    WHERE agents.name = ?
    ORDER BY agent_operations.date DESC
  ''', [name]);
  }

// ============== ملخص عمليات العميل ===========
  Future<Map<String, dynamic>> getSummaryByName(String name) async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "إضافة"
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM operations o
    INNER JOIN customers c ON o.client_id = c.id
    WHERE c.name = ? AND o.type = "إضافة"
    ''',
      [name],
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد"
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM operations o
    INNER JOIN customers c ON o.client_id = c.id
    WHERE c.name = ? AND o.type = "تسديد"
    ''',
      [name],
    );

    // استخراج القيم من النتائج
    final totalAdditions = additionsResult.first['totalAdditions'] ?? 0.0;
    final totalPayments = paymentsResult.first['totalPayments'] ?? 0.0;

    // حساب المبلغ المستحق
    final outstanding = (totalAdditions as double) - (totalPayments as double);

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'outstanding': outstanding,
    };
  }

// ============== ملخص عمليات الوكيل ===========
  Future<Map<String, dynamic>> getSummaryAgeentByName(String name) async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "إضافة"
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM agent_operations o
    INNER JOIN agents c ON o.agent_id = c.id
    WHERE c.name = ? AND o.type = "قرض"
    ''',
      [name],
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد"
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM agent_operations o
    INNER JOIN agents c ON o.agent_id = c.id
    WHERE c.name = ? AND o.type = "تسديد"
    ''',
      [name],
    );

    // استخراج القيم من النتائج
    final totalAdditions = additionsResult.first['totalAdditions'] ?? 0.0;
    final totalPayments = paymentsResult.first['totalPayments'] ?? 0.0;

    // حساب المبلغ المستحق
    final outstanding = (totalAdditions as double) - (totalPayments as double);

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'outstanding': outstanding,
    };
  }

//========= دالة لتوليد التاريخ  لطباعة الكشف =======
  String getFormattedDate() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy/MM/dd'); // تنسيق التاريخ
    return formatter.format(now);
  }

/* ===============================================
   ============== الحساب الشخصي  ===============
   ===============================================*/
  // دالة لإضافة عملية جديدة
  Future<void> insertDailyTransaction(
      double amount, String details, String type) async {
    final db = await database;
    final date = DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(DateTime.now()); // تنسيق التاريخ

    await db.insert(
      'daily_account',
      {
        'amount': amount,
        'details': details,
        'type': type,
        'date': date,
      },
    );
  }

//=============== استرجاع العمليات ===================
  Future<List<Map<String, dynamic>>> getDailyTransactions() async {
    final db = await database;
    return await db.query('daily_account',
        orderBy: 'date DESC'); // ترتيب العمليات حسب التاريخ
  }

//=============== حذف عملية ===================
  Future<int> deleteDailyTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'daily_account',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

//=============== تعديل  عملية ===================
  Future<int> updateDailyTransaction(
      int id, double amount, String details, String type) async {
    final db = await database;

    return await db.update(
      'daily_account',
      {
        'amount': amount,
        'details': details,
        'type': type,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

/* ===============================================
   ============== النسخ الاحتياطي  ===============
   ===============================================*/
//  انشاء نسخه احتياطيه محليه
  Future<File> exportDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // الحصول على مسار الذاكرة الخارجية
    final directory = Directory('/storage/emulated/0/Documents');
    if (!await directory.exists()) {
      throw Exception('لا يمكن الوصول إلى مجلد Documents');
    }

    // إنشاء مجلد "MritPro" داخل مجلد "Documents" إذا لم يكن موجودًا
    final mritProDir = Directory('${directory.path}/MritPro');
    if (!await mritProDir.exists()) {
      await mritProDir.create(recursive: true);
    }

    // نسخ قاعدة البيانات إلى مجلد MritPro
    final backupFile = File(
        '${mritProDir.path}/app_database_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
    await dbFile.copy(backupFile.path);

    return backupFile;
  }

  // استيراد قاعدة البيانات من ملف
  Future<void> importDatabase(File backupFile) async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // نسخ الملف الاحتياطي إلى موقع قاعدة البيانات
    await backupFile.copy(dbFile.path);

    // إعادة تهيئة قاعدة البيانات
    _database = await _initDatabase();
  }

  // الحصول على قائمة بجميع ملفات النسخ الاحتياطي
  Future<List<File>> getBackupFiles() async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('لا يمكن الوصول إلى مسار التخزين الخارجي');
    }

    final backupDir = Directory('${directory.path}/Backups');
    if (!await backupDir.exists()) {
      return [];
    }

    final files = backupDir.listSync().whereType<File>().toList();
    return files;
  }

// ======================================
  /// **التحقق من الاتصال بالإنترنت**
  Future<bool> _isConnectedToInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// **إنشاء أو استرجاع معرف مجلد `MritPro` في Google Drive**
  Future<String?> _getOrCreateBackupFolder(drive.DriveApi driveApi) async {
    // البحث عن مجلد MritPro في Google Drive
    const folderQuery =
        "name = 'MritPro' and mimeType = 'application/vnd.google-apps.folder'";
    final folderList = await driveApi.files.list(q: folderQuery);

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      return folderList.files!.first.id; // إرجاع معرف المجلد إذا كان موجودًا
    }

    // إنشاء مجلد جديد
    final drive.File folderMetadata = drive.File()
      ..name = "MritPro"
      ..mimeType = "application/vnd.google-apps.folder";

    final createdFolder = await driveApi.files.create(folderMetadata);
    return createdFolder.id;
  }

  /// **رفع النسخة الاحتياطية إلى Google Drive داخل مجلد `MritPro`**
  Future<String> backupToGoogleDrive() async {
    if (!await _isConnectedToInternet()) {
      return '❌ يرجى التحقق من الاتصال بالإنترنت';
    }

    try {
      final GoogleSignIn googleSignIn =
          GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return '⚠️ يجب تسجيل الدخول إلى Google أولًا';
      }

      final authHeaders = await googleUser.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(client);

      // إنشاء أو الحصول على مجلد MritPro
      final folderId = await _getOrCreateBackupFolder(driveApi);
      if (folderId == null) {
        return '❌ فشل في إنشاء مجلد MritPro في Google Drive';
      }

      // إنشاء النسخة الاحتياطية محليًا
      final backupFile = await exportDatabase();
      final file = drive.File()
        ..name = 'backup_${DateTime.now().millisecondsSinceEpoch}.db'
        ..parents = [folderId]; // وضع الملف داخل مجلد MritPro

      final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());
      await driveApi.files.create(file, uploadMedia: media);

      return '✅ تم رفع النسخة الاحتياطية إلى Google Drive بنجاح';
    } catch (e) {
      return '❌ فشل في رفع النسخة الاحتياطية: $e';
    }
  }

  /// **استعادة أحدث نسخة احتياطية من Google Drive**
  Future<String> restoreBackupFromGoogleDrive() async {
    if (!await _isConnectedToInternet()) {
      return '❌ يرجى التحقق من الاتصال بالإنترنت';
    }

    try {
      final GoogleSignIn googleSignIn =
          GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return '⚠️ يجب تسجيل الدخول إلى Google أولًا';
      }

      final authHeaders = await googleUser.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(client);

      // البحث عن مجلد MritPro
      final folderId = await _getOrCreateBackupFolder(driveApi);
      if (folderId == null) {
        return '❌ لم يتم العثور على مجلد MritPro في Google Drive';
      }

      // البحث عن أحدث ملف نسخة احتياطية
      final fileList = await driveApi.files.list(
        q: "'$folderId' in parents",
        orderBy: "createdTime desc",
        pageSize: 1,
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return '❌ لا توجد نسخ احتياطية متاحة في Google Drive';
      }

      final latestBackup = fileList.files!.first;
      final fileId = latestBackup.id;

      if (fileId == null) {
        return '❌ فشل في العثور على الملف';
      }

      // تحميل الملف
      final mediaStream = await driveApi.files.get(fileId,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final filePath =
          "/storage/emulated/0/Documents/MritPro/restored_database.db";
      final file = File(filePath);
      final sink = file.openWrite();
      await sink.addStream(mediaStream.stream);
      await sink.close();

      return '✅ تم استعادة  النسخة الاحتياطية الاحدث بنجاح إلى: $filePath';
    } catch (e) {
      return '❌ فشل في استعادة النسخة الاحتياطية: $e';
    }
  }

// ======================================
}

/// **كلاس لتسهيل التعامل مع Google API**
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
/*
//                              الاخير
 import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:intl/intl.dart'; // مكتبة للتعامل مع التاريخ

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

// ============================================
//           ادارة قاعدة البيانات
// ============================================
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');
// حذف قاعدة البيانات إذا كانت موجودة (للتطوير فقط)
    // await deleteDatabase(path);
    return await openDatabase(
      path,
      version: 5, // زيادة رقم الإصدار لأننا أضفنا جداول جديدة
      onCreate: _onCreate,
    );
  }

//  انشاء الجدوال
  Future<void> _onCreate(Database db, int version) async {
    // إنشاء جدول العملاء
    await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL
    )
  ''');

    // إنشاء جدول العمليات
    await db.execute('''
    CREATE TABLE operations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL,
      amount REAL,
      details TEXT,
      type TEXT,
      date TEXT,
      FOREIGN KEY (client_id) REFERENCES customers (id)
    )
  ''');

    // إنشاء جدول الحساب اليومي
    await db.execute('''
    CREATE TABLE daily_account (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      details TEXT NOT NULL,
      type TEXT NOT NULL,
      date TEXT NOT NULL
    )
  ''');

    // إنشاء جدول الوكلاء
    await db.execute('''
    CREATE TABLE agents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL
    )
  ''');

    // إنشاء جدول عمليات الوكلاء
    await db.execute('''
    CREATE TABLE agent_operations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agent_id INTEGER NOT NULL,
      amount REAL,
      details TEXT,
      type TEXT,
      date TEXT,
      FOREIGN KEY (agent_id) REFERENCES agents (id)
    )
  ''');
  }

  // دالة للتحقق من وجود جدول
  Future<bool> doesTableExist(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'",
    );
    return result.isNotEmpty;
  }

// ================================================================
//               ادارة العملاء والتجار
// ================================================================

  // إضافة عميل جديد
  Future<int> insertCustomer(String name, String phone) async {
    final db = await database;

    // إزالة الفراغات من بداية ونهاية الاسم
    String trimmedName = name.trim();

    return await db.insert('customers', {'name': trimmedName, 'phone': phone});
  }

  // استرجاع جميع العملاء
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query('customers');
  }

  // تحديث بيانات عميل
  Future<int> updateCustomer(int id, String name, String phone) async {
    final db = await database;
    String trimmedName = name.trim();

    return await db.update(
      'customers',
      {'name': trimmedName, 'phone': phone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // حذف عميل
  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// إضافة وكيل جديد
  Future<int> insertAgent(String name, String phone) async {
    final db = await database;

    // إزالة الفراغات من بداية ونهاية الاسم
    String trimmedName = name.trim();

    return await db.insert('agents', {'name': trimmedName, 'phone': phone});
  }

  // استرجاع جميع الوكلاء
  Future<List<Map<String, dynamic>>> getAllAgents() async {
    final db = await database;
    return await db.query('agents');
  }

  // حذف وكيل
  Future<int> deleteAgent(int id) async {
    final db = await database;
    return await db.delete('agents', where: 'id = ?', whereArgs: [id]);
  }

  // تعديل وكيل
  Future<int> updateAgent(int id, String name, String phone) async {
    final db = await database;
    return await db.update(
      'agents',
      {'name': name, 'phone': phone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
// ==========================================

/* ===============================================
   ============== اضافة عملية====================
   ===============================================*/

/* ==================================
   ============== العملاء ============
   ==================================*/
  //==========  التحقق من وجود العميل=========
  Future<bool> doesClientExist(String name) async {
    final db = await database;
    final result = await db.query(
      'customers',
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.isNotEmpty;
  }

//  =============  بحث الاسماء المطابقة لما يكتب في الحقل ==============
  Future<List<String>> getClientNames(String query) async {
    final db = await database;

    // البحث عن الأسماء التي تحتوي على النص المدخل
    final result = await db.rawQuery(
      "SELECT name FROM customers WHERE name LIKE ?",
      ['%$query%'],
    );

    // تحويل النتائج إلى قائمة من النصوص
    return result.map((row) => row['name'].toString()).toList();
  }

// =============== ارجاع الاسماء المطابقه للعملاء=============
  Future<List<Map<String, dynamic>>> searchClientsByName(String query) async {
    final db = await database;
    return await db.query(
      'customers',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: 10, // تحديد عدد النتائج
    );
  }

// ============   اضافة عمليه لعميل ===========
  Future<void> insertOperation(
      int clientId, double amount, String details, String type) async {
    final db = await database;
    String creetDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    await db.insert('operations', {
      'client_id': clientId, // حفظ ID العميل
      'amount': amount,
      'details': details,
      'type': type,
      'date': creetDate,
    });
  }

// ===============ارجاع العمليات وعرضها للعملاء======================
  Future<List<Map<String, dynamic>>> getOperationsByDate(DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return await db.rawQuery('''
    SELECT 
      operations.id AS operation_id, 
      operations.client_id, 
      operations.amount, 
      operations.details, 
      operations.type, 
      operations.date,
      customers.name AS client_name
    FROM operations
    LEFT JOIN customers ON operations.client_id = customers.id
    WHERE DATE(operations.date) = ?
    ORDER BY operations.id DESC
  ''', [formattedDate]);
  }

// ===================حذف عملية لعميل ==================
  Future<int> deleteOperation(int operationId) async {
    final db = await database;
    return await db.delete(
      'operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

// ===================تعديل  عملية  لعميل==================
  Future<int> updateOperation(
      int id, double amount, String details, String type) async {
    final db = await database;

    // تحديث التاريخ عند التعديل
    // String updatedDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    return await db.update(
      'operations',
      {
        'amount': amount,
        'details': details,
        'type': type,
        // 'date': updatedDate,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

//===========  ملخص العمليات للعملاء =========
  Future<Map<String, double>> getSummaryByDate(DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // جلب إجمالي التسديدات
    final totalPaymentsResult = await db.rawQuery('''
    SELECT SUM(amount) AS total_payments
    FROM operations
    WHERE DATE(date) = ? AND type = 'تسديد'
  ''', [formattedDate]);

    // جلب إجمالي الإضافات
    final totalAdditionsResult = await db.rawQuery('''
    SELECT SUM(amount) AS total_additions
    FROM operations
    WHERE DATE(date) = ? AND type = 'إضافة'
  ''', [formattedDate]);

    // تحويل القيم إلى double مع التعامل مع القيم الفارغة
    final double totalPayments =
        (totalPaymentsResult.first['total_payments'] as num?)?.toDouble() ??
            0.0;
    final double totalAdditions =
        (totalAdditionsResult.first['total_additions'] as num?)?.toDouble() ??
            0.0;

    return {
      'total_payments': totalPayments,
      'total_additions': totalAdditions,
      'balance': totalPayments - totalAdditions,
    };
  }

  Future<Map<String, dynamic>> getTotalSummary() async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "إضافة" لجميع العملاء
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM operations o
    WHERE o.type = "إضافة"
    ''',
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد" لجميع العملاء
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM operations o
    WHERE o.type = "تسديد"
    ''',
    );

    // استعلام للحصول على عدد العملاء
    final customersCountResult = await db.rawQuery(
      '''
    SELECT COUNT(*) as totalCustomers
    FROM customers
    ''',
    );

    // استخراج القيم من النتائج
    final totalAdditions =
        additionsResult.first['totalAdditions'] as double? ?? 0.0;
    final totalPayments =
        paymentsResult.first['totalPayments'] as double? ?? 0.0;
    final totalCustomers =
        customersCountResult.first['totalCustomers'] as int? ?? 0;

    // حساب المبلغ المستحق الكلي
    final totalOutstanding = totalAdditions - totalPayments;

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'totalOutstanding': totalOutstanding,
      'totalCustomers': totalCustomers,
    };
  }

  Future<Map<String, dynamic>> getTotalAgeensSummary() async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "قرض" لجميع الوكلاء
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM agent_operations o
    WHERE o.type = "قرض"
    ''',
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد" لجميع الوكلاء
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM agent_operations o
    WHERE o.type = "تسديد"
    ''',
    );

    // استعلام للحصول على عدد الوكلاء
    final customersCountResult = await db.rawQuery(
      '''
    SELECT COUNT(*) as totalCustomers
    FROM agents
    ''',
    );

    // استخراج القيم من النتائج
    final totalAdditions =
        additionsResult.first['totalAdditions'] as double? ?? 0.0;
    final totalPayments =
        paymentsResult.first['totalPayments'] as double? ?? 0.0;
    final totalCustomers =
        customersCountResult.first['totalCustomers'] as int? ?? 0;

    // حساب المبلغ المستحق الكلي
    final totalOutstanding = totalAdditions - totalPayments;

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'totalOutstanding': totalOutstanding,
      'totalCustomers': totalCustomers,
    };
  }

// ============== ملخص عمليات العميل ===========
  Future<Map<String, dynamic>> getSummaryByName(String name) async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "إضافة"
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM operations o
    INNER JOIN customers c ON o.client_id = c.id
    WHERE c.name = ? AND o.type = "إضافة"
    ''',
      [name],
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد"
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM operations o
    INNER JOIN customers c ON o.client_id = c.id
    WHERE c.name = ? AND o.type = "تسديد"
    ''',
      [name],
    );

    // استخراج القيم من النتائج
    final totalAdditions = additionsResult.first['totalAdditions'] ?? 0.0;
    final totalPayments = paymentsResult.first['totalPayments'] ?? 0.0;

    // حساب المبلغ المستحق
    final outstanding = (totalAdditions as double) - (totalPayments as double);

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'outstanding': outstanding,
    };
  }

// ============== ملخص عمليات الوكيل ===========
  Future<Map<String, dynamic>> getSummaryAgeentByName(String name) async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "إضافة"
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM agent_operations o
    INNER JOIN agents c ON o.agent_id = c.id
    WHERE c.name = ? AND o.type = "قرض"
    ''',
      [name],
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد"
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM agent_operations o
    INNER JOIN agents c ON o.agent_id = c.id
    WHERE c.name = ? AND o.type = "تسديد"
    ''',
      [name],
    );

    // استخراج القيم من النتائج
    final totalAdditions = additionsResult.first['totalAdditions'] ?? 0.0;
    final totalPayments = paymentsResult.first['totalPayments'] ?? 0.0;

    // حساب المبلغ المستحق
    final outstanding = (totalAdditions as double) - (totalPayments as double);

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'outstanding': outstanding,
    };
  }

/* ==================================
   ============== الوكلاء ============
   ==================================*/
// ============ البحث عن أسماء الوكلاء المتطابقة ==============
  Future<List<String>> getAgentNames(String query) async {
    final db = await database;

    // البحث عن الأسماء التي تحتوي على النص المدخل
    final result = await db.rawQuery(
      "SELECT name FROM agents WHERE name LIKE ?",
      ['%$query%'],
    );

    // تحويل النتائج إلى قائمة من النصوص
    return result.map((row) => row['name'].toString()).toList();
  }

// ============ إرجاع أسماء الوكلاء المتطابقة ===============
  Future<List<Map<String, dynamic>>> searchAgentsByName(String query) async {
    final db = await database;
    return await db.query(
      'agents',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: 10, // تحديد عدد النتائج
    );
  }

// ============ إضافة عملية لوكيل ===============
  Future<void> insertAgentOperation(
      int agentId, double amount, String details, String type) async {
    final db = await database;
    String currentDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    await db.insert('agent_operations', {
      'agent_id': agentId, // حفظ ID الوكيل
      'amount': amount,
      'details': details,
      'type': type,
      'date': currentDate,
    });
  }

// ===============ارجاع العمليات وعرضها للوكلاء======================
  Future<List<Map<String, dynamic>>> getAgentOperationsByDate(
      DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return await db.rawQuery('''
  SELECT 
    agent_operations.id AS operation_id, 
    agent_operations.agent_id, 
    agent_operations.amount, 
    agent_operations.details, 
    agent_operations.type, 
    agent_operations.date,
    agents.name AS agent_name
  FROM agent_operations
  LEFT JOIN agents ON agent_operations.agent_id = agents.id
  WHERE DATE(agent_operations.date) = ?
  ORDER BY agent_operations.id DESC
  ''', [formattedDate]);
  }

// ===================حذف عملية لوكيل ==================
  Future<int> deleteAgentOperation(int operationId) async {
    final db = await database;
    return await db.delete(
      'agent_operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

// ===================تعديل  عملية  لوكيل==================
  Future<int> updateAgentOperation(
      int id, double amount, String details, String type) async {
    final db = await database;

    // تحديث البيانات
    return await db.update(
      'agent_operations',
      {
        'amount': amount,
        'details': details,
        'type': type,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

//===========  ملخص العمليات للوكلاء =========
  Future<Map<String, double>> getAgentSummaryByDate(DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // جلب إجمالي التسديدات
    final totalPaymentsResult = await db.rawQuery('''
  SELECT SUM(amount) AS total_payments
  FROM agent_operations
  WHERE DATE(date) = ? AND type = 'تسديد'
  ''', [formattedDate]);

    // جلب إجمالي الإضافات
    final totalAdditionsResult = await db.rawQuery('''
  SELECT SUM(amount) AS total_additions
  FROM agent_operations
  WHERE DATE(date) = ? AND type = 'قرض'
  ''', [formattedDate]);

    // تحويل القيم إلى double مع التعامل مع القيم الفارغة
    final double totalPayments =
        (totalPaymentsResult.first['total_payments'] as num?)?.toDouble() ??
            0.0;
    final double totalAdditions =
        (totalAdditionsResult.first['total_additions'] as num?)?.toDouble() ??
            0.0;

    return {
      'total_payments': totalPayments,
      'total_additions': totalAdditions,
      'balance': totalPayments - totalAdditions,
    };
  }

/* ===============================================
   ============== بحث عن كشف عميل ===============
   ===============================================*/

  //  ============= بحث عن عميل ===============
  Future<List<Map<String, dynamic>>> getOperationsByClientName(
      String name) async {
    final db = await database;

    // استعلام لاسترجاع العمليات المرتبطة باسم العميل المدخل
    return await db.rawQuery('''
    SELECT 
      operations.id AS operation_id, 
      operations.amount, 
      operations.details, 
      operations.type, 
      operations.date, 
      customers.name AS client_name
    FROM operations
    INNER JOIN customers ON operations.client_id = customers.id
    WHERE customers.name = ?
    ORDER BY operations.date DESC
  ''', [name]);
  }

  //  ============= بحث عن وكيل ===============
  Future<List<Map<String, dynamic>>> getOperationsByAgenntName(
      String name) async {
    final db = await database;

    // استعلام لاسترجاع العمليات المرتبطة باسم العميل المدخل
    return await db.rawQuery('''
    SELECT 
      agent_operations.id AS agent_id, 
      agent_operations.amount, 
      agent_operations.details, 
      agent_operations.type, 
      agent_operations.date, 
      agents.name AS agent_id
    FROM agent_operations
    INNER JOIN agents ON agent_operations.agent_id = agents.id
    WHERE agents.name = ?
    ORDER BY agent_operations.date DESC
  ''', [name]);
  }

/* // ============== ملخص عمليات العميل ===========
  Future<Map<String, dynamic>> getSummaryByName(String name) async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "إضافة"
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM operations o
    INNER JOIN customers c ON o.client_id = c.id
    WHERE c.name = ? AND o.type = "إضافة"
    ''',
      [name],
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد"
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM operations o
    INNER JOIN customers c ON o.client_id = c.id
    WHERE c.name = ? AND o.type = "تسديد"
    ''',
      [name],
    );

    // استخراج القيم من النتائج
    final totalAdditions = additionsResult.first['totalAdditions'] ?? 0.0;
    final totalPayments = paymentsResult.first['totalPayments'] ?? 0.0;

    // حساب المبلغ المستحق
    final outstanding = (totalAdditions as double) - (totalPayments as double);

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'outstanding': outstanding,
    };
  }
 */
//========= دالة لتوليد التاريخ  لطباعة الكشف =======
  String getFormattedDate() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy/MM/dd'); // تنسيق التاريخ
    return formatter.format(now);
  }

/* ===============================================
   ============== الحساب الشخصي  ===============
   ===============================================*/
  // دالة لإضافة عملية جديدة
  Future<void> insertDailyTransaction(
      double amount, String details, String type) async {
    final db = await database;
    final date =
        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()); // تنسيق التاريخ

    await db.insert(
      'daily_account',
      {
        'amount': amount,
        'details': details,
        'type': type,
        'date': date,
      },
    );
  }

//=============== استرجاع العمليات ===================
  Future<List<Map<String, dynamic>>> getDailyTransactions() async {
    final db = await database;
    return await db.query('daily_account',
        orderBy: 'date DESC'); // ترتيب العمليات حسب التاريخ
  }

//=============== حذف عملية ===================
  Future<int> deleteDailyTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'daily_account',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

//=============== تعديل  عملية ===================
  Future<int> updateDailyTransaction(
      int id, double amount, String details, String type) async {
    final db = await database;
    // final date =
    // DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()); // تحديث التاريخ

    return await db.update(
      'daily_account',
      {
        'amount': amount,
        'details': details,
        'type': type,
        // 'date': date,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

/* ===============================================
   ============== النسخ الاحتياطي  ===============
   ===============================================*/

  Future<File> exportDatabase() async {
    // final db = await database;
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // الحصول على مسار الذاكرة الخارجية
    final directory = Directory('/storage/emulated/0/Documents');
    if (!await directory.exists()) {
      throw Exception('لا يمكن الوصول إلى مجلد Documents');
    }

    // إنشاء مجلد "MritPro" داخل مجلد "Documents" إذا لم يكن موجودًا
    final mritProDir = Directory('${directory.path}/MritPro');
    if (!await mritProDir.exists()) {
      await mritProDir.create(recursive: true);
    }

    // نسخ قاعدة البيانات إلى مجلد MritPro
    final backupFile = File(
        '${mritProDir.path}/app_database_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
    await dbFile.copy(backupFile.path);

    return backupFile;
  }

  // استيراد قاعدة البيانات من ملف
  Future<void> importDatabase(File backupFile) async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // نسخ الملف الاحتياطي إلى موقع قاعدة البيانات
    await backupFile.copy(dbFile.path);

    // إعادة تهيئة قاعدة البيانات
    _database = await _initDatabase();
  }

  // الحصول على قائمة بجميع ملفات النسخ الاحتياطي
  Future<List<File>> getBackupFiles() async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('لا يمكن الوصول إلى مسار التخزين الخارجي');
    }

    final backupDir = Directory('${directory.path}/Backups');
    if (!await backupDir.exists()) {
      return [];
    }

    final files = backupDir.listSync().whereType<File>().toList();
    return files;
  }

/*   Future<int> insertAgentOperation(
    int agentId,
    double amount,
    String details,
    String type,
  ) async {
    final db = await database;
    final date = DateFormat('yyyy-MM-dd HH:mm')
        .format(DateTime.now()); // إنشاء التاريخ هنا

    return await db.insert('agent_operations', {
      'agent_id': agentId,
      'amount': amount,
      'details': details,
      'type': type,
      'date': date, // استخدام التاريخ المنسق
    });
  }

  Future<List<Map<String, dynamic>>> getAllAgentOperations() async {
    final db = await database;
    return await db.query('agent_operations');
  }

// ================================================
  Future<List<String>> getAllCustomerNames() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('agents');
    return List.generate(maps.length, (i) => maps[i]['name'] as String);
  }
 */

// ================================================
}


 */


/* 

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

/*   Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }
  // إنشاء جدول العملاء

  Future<void> _onCreate(Database db, int version) async {
    // إنشاء جدول العملاء
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');
    await db.execute('''
    CREATE TABLE operations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL,
      amount REAL,
      details TEXT,
      type TEXT,
      date TEXT,
      FOREIGN KEY (client_id) REFERENCES clients (id)
  )    
    ''');
        await db.execute('''
      CREATE TABLE daily_account (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        details TEXT NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }
 */

  // حذف قاعدة البيانات إذا كانت موجودة (للتطوير فقط)
  // await deleteDatabase(path);
/* 
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');

    return await openDatabase(
      path,
      version: 2, // زيادة رقم الإصدار
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // إنشاء جدول العملاء
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');

    // إنشاء جدول العمليات
    await db.execute('''
      CREATE TABLE operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        amount REAL,
        details TEXT,
        type TEXT,
        date TEXT,
        FOREIGN KEY (client_id) REFERENCES customers (id)
      )
    ''');

    // إنشاء جدول الحساب اليومي
    await db.execute('''
      CREATE TABLE daily_account (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        details TEXT NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }
 */
// ============================================
// ============================================
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');
// حذف قاعدة البيانات إذا كانت موجودة (للتطوير فقط)
    // await deleteDatabase(path);
    return await openDatabase(
      path,
      version: 5, // زيادة رقم الإصدار لأننا أضفنا جداول جديدة
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // إنشاء جدول العملاء
    await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL
    )
  ''');

    // إنشاء جدول العمليات
    await db.execute('''
    CREATE TABLE operations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL,
      amount REAL,
      details TEXT,
      type TEXT,
      date TEXT,
      FOREIGN KEY (client_id) REFERENCES customers (id)
    )
  ''');

    // إنشاء جدول الحساب اليومي
    await db.execute('''
    CREATE TABLE daily_account (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      details TEXT NOT NULL,
      type TEXT NOT NULL,
      date TEXT NOT NULL
    )
  ''');

    // إنشاء جدول الوكلاء
    await db.execute('''
    CREATE TABLE agents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL
    )
  ''');

    // إنشاء جدول عمليات الوكلاء
    await db.execute('''
    CREATE TABLE agent_operations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agent_id INTEGER NOT NULL,
      amount REAL,
      details TEXT,
      type TEXT,
      date TEXT,
      FOREIGN KEY (agent_id) REFERENCES agents (id)
    )
  ''');
  }

// ============================================
// ============================================
  // دالة للتحقق من وجود جدول
  Future<bool> doesTableExist(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'",
    );
    return result.isNotEmpty;
  }

// إضافة عميل جديد
  Future<int> insertCustomer(String name, String phone) async {
    final db = await database;

    // إزالة الفراغات من بداية ونهاية الاسم
    String trimmedName = name.trim();

    return await db.insert('customers', {'name': trimmedName, 'phone': phone});
  }

// ==========================================
// إضافة وكيل جديد
  Future<int> insertAgent(String name, String phone) async {
    final db = await database;

    // إزالة الفراغات من بداية ونهاية الاسم
    String trimmedName = name.trim();

    return await db.insert('agents', {'name': trimmedName, 'phone': phone});
  }

  // استرجاع جميع الوكلاء
  Future<List<Map<String, dynamic>>> getAllAgents() async {
    final db = await database;
    return await db.query('agents');
  }

  // حذف وكيل
  Future<int> deleteAgent(int id) async {
    final db = await database;
    return await db.delete('agents', where: 'id = ?', whereArgs: [id]);
  }

  // تعديل وكيل
  Future<int> updateAgent(int id, String name, String phone) async {
    final db = await database;
    return await db.update(
      'agents',
      {'name': name, 'phone': phone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// ==========================================
  // استرجاع جميع العملاء
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query('customers');
  }

  // تحديث بيانات عميل
  Future<int> updateCustomer(int id, String name, String phone) async {
    final db = await database;
    String trimmedName = name.trim();

    return await db.update(
      'customers',
      {'name': trimmedName, 'phone': phone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // حذف عميل
  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// =====================================
  // NEW
// =====================================
  Future<bool> doesClientExist(String name) async {
    final db = await database;
    final result = await db.query(
      'customers',
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.isNotEmpty;
  }

  Future<int> addClient(String name, String phone) async {
    final db = await database;
    return await db.insert(
      'customers',
      {'name': name, 'phone': phone},
    );
  }

  Future<void> insertOperation(
      int clientId, double amount, String details, String type) async {
    final db = await database;
    String creetDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    await db.insert('operations', {
      'client_id': clientId, // حفظ ID العميل
      'amount': amount,
      'details': details,
      'type': type,
      'date': creetDate,
    });
  }

// =====================================
// =====================================

  Future<List<String>> getClientNames(String query) async {
    final db = await database;

    // البحث عن الأسماء التي تحتوي على النص المدخل
    final result = await db.rawQuery(
      "SELECT name FROM customers WHERE name LIKE ?",
      ['%$query%'],
    );

    // تحويل النتائج إلى قائمة من النصوص
    return result.map((row) => row['name'].toString()).toList();
  }

  Future<List<Map<String, dynamic>>> searchClientsByName(String query) async {
    final db = await database;
    return await db.query(
      'customers',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: 10, // تحديد عدد النتائج
    );
  }

/* 
  Future<List<Map<String, dynamic>>> getLastTenOperationsWithNames() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT 
      operations.id AS operation_id, 
      operations.client_id, 
      operations.amount, 
      operations.details, 
      operations.type, 
      operations.date,
      customers.name AS client_name
    FROM operations
    LEFT JOIN customers ON operations.client_id = customers.id
    ORDER BY operations.id DESC
    LIMIT 50
  ''');
  }
 */
  Future<List<Map<String, dynamic>>> getOperationsByDate(DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return await db.rawQuery('''
    SELECT 
      operations.id AS operation_id, 
      operations.client_id, 
      operations.amount, 
      operations.details, 
      operations.type, 
      operations.date,
      customers.name AS client_name
    FROM operations
    LEFT JOIN customers ON operations.client_id = customers.id
    WHERE DATE(operations.date) = ?
    ORDER BY operations.id DESC
  ''', [formattedDate]);
  }

  Future<int> deleteOperation(int operationId) async {
    final db = await database;
    return await db.delete(
      'operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  Future<int> updateOperation(
      int id, double amount, String details, String type) async {
    final db = await database;

    // تحديث التاريخ عند التعديل
    // String updatedDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    return await db.update(
      'operations',
      {
        'amount': amount,
        'details': details,
        'type': type,
        // 'date': updatedDate,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getOperationsByClientName(
      String name) async {
    final db = await database;

    // استعلام لاسترجاع العمليات المرتبطة باسم العميل المدخل
    return await db.rawQuery('''
    SELECT 
      operations.id AS operation_id, 
      operations.amount, 
      operations.details, 
      operations.type, 
      operations.date, 
      customers.name AS client_name
    FROM operations
    INNER JOIN customers ON operations.client_id = customers.id
    WHERE customers.name = ?
    ORDER BY operations.date DESC
  ''', [name]);
  }

  Future<Map<String, dynamic>> getSummaryByName(String name) async {
    final db = await database;

    // استعلام للحصول على إجمالي المبالغ التي نوعها "إضافة"
    final additionsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalAdditions
    FROM operations o
    INNER JOIN customers c ON o.client_id = c.id
    WHERE c.name = ? AND o.type = "إضافة"
    ''',
      [name],
    );

    // استعلام للحصول على إجمالي المبالغ التي نوعها "تسديد"
    final paymentsResult = await db.rawQuery(
      '''
    SELECT SUM(o.amount) as totalPayments
    FROM operations o
    INNER JOIN customers c ON o.client_id = c.id
    WHERE c.name = ? AND o.type = "تسديد"
    ''',
      [name],
    );

    // استخراج القيم من النتائج
    final totalAdditions = additionsResult.first['totalAdditions'] ?? 0.0;
    final totalPayments = paymentsResult.first['totalPayments'] ?? 0.0;

    // حساب المبلغ المستحق
    final outstanding = (totalAdditions as double) - (totalPayments as double);

    return {
      'totalAdditions': totalAdditions,
      'totalPayments': totalPayments,
      'outstanding': outstanding,
    };
  }

  // دالة لتوليد التاريخ بتنسيق yyyy/MM/dd باستخدام intl
  String getFormattedDate() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy/MM/dd'); // تنسيق التاريخ
    return formatter.format(now);
  }

// ===================================

  // دالة لإضافة عملية جديدة
  Future<void> insertDailyTransaction(
      double amount, String details, String type) async {
    final db = await database;
    final date =
        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()); // تنسيق التاريخ

    await db.insert(
      'daily_account',
      {
        'amount': amount,
        'details': details,
        'type': type,
        'date': date,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getDailyTransactions() async {
    final db = await database;
    return await db.query('daily_account',
        orderBy: 'date DESC'); // ترتيب العمليات حسب التاريخ
  }

  Future<int> deleteDailyTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'daily_account',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateDailyTransaction(
      int id, double amount, String details, String type) async {
    final db = await database;
    // final date =
    // DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()); // تحديث التاريخ

    return await db.update(
      'daily_account',
      {
        'amount': amount,
        'details': details,
        'type': type,
        // 'date': date,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// =================================================
/*   // تصدير قاعدة البيانات إلى ملف
  Future<File> exportDatabase() async {
    final db = await database;
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // الحصول على مسار التخزين الخارجي
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('لا يمكن الوصول إلى مسار التخزين الخارجي');
    }

    // إنشاء مجلد "Backups" إذا لم يكن موجودًا
    final backupDir = Directory('${directory.path}/Backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    // نسخ قاعدة البيانات إلى مجلد النسخ الاحتياطي
    final backupFile = File(
        '${backupDir.path}/app_database_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
    await dbFile.copy(backupFile.path);

    return backupFile;
  }

  // استيراد قاعدة البيانات من ملف
  Future<void> importDatabase(File backupFile) async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // نسخ الملف الاحتياطي إلى موقع قاعدة البيانات
    await backupFile.copy(dbFile.path);

    // إعادة تهيئة قاعدة البيانات
    _database = await _initDatabase();
  }

  // الحصول على قائمة بجميع ملفات النسخ الاحتياطي
  Future<List<File>> getBackupFiles() async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('لا يمكن الوصول إلى مسار التخزين الخارجي');
    }

    final backupDir = Directory('${directory.path}/Backups');
    if (!await backupDir.exists()) {
      return [];
    }

    final files = backupDir.listSync().whereType<File>().toList();
    return files;
  }
 */

// =====================================
  /*  // تصدير قاعدة البيانات إلى ملف
  Future<File> exportDatabase() async {
    final db = await database;
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // الحصول على مسار التخزين الخارجي
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('لا يمكن الوصول إلى مسار التخزين الخارجي');
    }

    // إنشاء مجلد "Backups" إذا لم يكن موجودًا
    final backupDir = Directory('${directory.path}/Backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    // نسخ قاعدة البيانات إلى مجلد النسخ الاحتياطي
    final backupFile = File(
        '${backupDir.path}/app_database_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
    await dbFile.copy(backupFile.path);

    return backupFile;
  }
 */

/*   // تصدير قاعدة البيانات إلى ملف
  Future<File> exportDatabase() async {
    final db = await database;
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // الحصول على مسار مجلد Documents في الذاكرة الداخلية
    final directory = await getApplicationDocumentsDirectory();

    // إنشاء مجلد "MritPro" داخل مجلد Documents إذا لم يكن موجودًا
    final mritProDir = Directory('${directory.path}/MritPro');
    if (!await mritProDir.exists()) {
      await mritProDir.create(recursive: true);
    }

    // نسخ قاعدة البيانات إلى مجلد MritPro
    final backupFile = File(
        '${mritProDir.path}/app_database_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
    await dbFile.copy(backupFile.path);

    return backupFile;
  }
 */
/*   // تصدير قاعدة البيانات إلى ملف
  Future<File> exportDatabase() async {
    final db = await database;
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // الحصول على مسار الذاكرة الخارجية (الظاهرة للمستخدم)
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('لا يمكن الوصول إلى الذاكرة الخارجية');
    }

    // إنشاء مجلد "Documents/MritPro" إذا لم يكن موجودًا
    final mritProDir = Directory('${directory.path}/Documents/MritPro');
    if (!await mritProDir.exists()) {
      await mritProDir.create(recursive: true);
    }

    // نسخ قاعدة البيانات إلى مجلد MritPro
    final backupFile = File(
        '${mritProDir.path}/app_database_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
    await dbFile.copy(backupFile.path);

    return backupFile;
  }
 */

  /*  // تصدير قاعدة البيانات إلى ملف
  Future<File> exportDatabase() async {
    final db = await database;
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // الحصول على مسار الذاكرة الخارجية (الجذر)
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('لا يمكن الوصول إلى الذاكرة الخارجية');
    }

    // إنشاء مجلد "Documents/MritPro" في الجذر إذا لم يكن موجودًا
    final mritProDir = Directory('/storage/emulated/0/Documents/MritPro');
    if (!await mritProDir.exists()) {
      await mritProDir.create(recursive: true);
    }

    // نسخ قاعدة البيانات إلى مجلد MritPro
    final backupFile = File(
        '${mritProDir.path}/app_database_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
    await dbFile.copy(backupFile.path);

    return backupFile;
  }
 */
/* 
  Future<File> exportDatabase() async {
    final db = await database;
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // الحصول على مسار الذاكرة الخارجية
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('لا يمكن الوصول إلى الذاكرة الخارجية');
    }

    // إنشاء مجلد "Documents/MritPro" إذا لم يكن موجودًا
    final mritProDir = Directory('${directory.path}/Documents/MritPro');
    if (!await mritProDir.exists()) {
      await mritProDir.create(recursive: true);
    }

    // نسخ قاعدة البيانات إلى مجلد MritPro
    final backupFile = File(
        '${mritProDir.path}/app_database_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
    await dbFile.copy(backupFile.path);

    return backupFile;
  }
 */

  Future<File> exportDatabase() async {
    final db = await database;
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // الحصول على مسار الذاكرة الخارجية
    final directory = Directory('/storage/emulated/0/Documents');
    if (!await directory.exists()) {
      throw Exception('لا يمكن الوصول إلى مجلد Documents');
    }

    // إنشاء مجلد "MritPro" داخل مجلد "Documents" إذا لم يكن موجودًا
    final mritProDir = Directory('${directory.path}/MritPro');
    if (!await mritProDir.exists()) {
      await mritProDir.create(recursive: true);
    }

    // نسخ قاعدة البيانات إلى مجلد MritPro
    final backupFile = File(
        '${mritProDir.path}/app_database_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
    await dbFile.copy(backupFile.path);

    return backupFile;
  }

  // استيراد قاعدة البيانات من ملف
  Future<void> importDatabase(File backupFile) async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app_database.db'));

    // نسخ الملف الاحتياطي إلى موقع قاعدة البيانات
    await backupFile.copy(dbFile.path);

    // إعادة تهيئة قاعدة البيانات
    _database = await _initDatabase();
  }

  // الحصول على قائمة بجميع ملفات النسخ الاحتياطي
  Future<List<File>> getBackupFiles() async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('لا يمكن الوصول إلى مسار التخزين الخارجي');
    }

    final backupDir = Directory('${directory.path}/Backups');
    if (!await backupDir.exists()) {
      return [];
    }

    final files = backupDir.listSync().whereType<File>().toList();
    return files;
  }

/* 
Future<Map<String, double>> getSummaryByDate(DateTime date) async {
  final db = await database;
  final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  // جلب إجمالي التسديدات
  final totalPaymentsResult = await db.rawQuery('''
    SELECT SUM(amount) AS total_payments
    FROM operations
    WHERE DATE(date) = ? AND type = 'تسديد'
  ''', [formattedDate]);

  // جلب إجمالي الإضافات
  final totalAdditionsResult = await db.rawQuery('''
    SELECT SUM(amount) AS total_additions
    FROM operations
    WHERE DATE(date) = ? AND type = 'إضافة'
  ''', [formattedDate]);

  final double totalPayments = totalPaymentsResult.first['total_payments'] ?? 0.0; // خطاء
  final double totalAdditions = totalAdditionsResult.first['total_additions'] ?? 0.0; // خطاء

  return {
    'total_payments': totalPayments,
    'total_additions': totalAdditions,
    'balance': totalPayments - totalAdditions,
  };
}

 */

  Future<Map<String, double>> getSummaryByDate(DateTime date) async {
    final db = await database;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // جلب إجمالي التسديدات
    final totalPaymentsResult = await db.rawQuery('''
    SELECT SUM(amount) AS total_payments
    FROM operations
    WHERE DATE(date) = ? AND type = 'تسديد'
  ''', [formattedDate]);

    // جلب إجمالي الإضافات
    final totalAdditionsResult = await db.rawQuery('''
    SELECT SUM(amount) AS total_additions
    FROM operations
    WHERE DATE(date) = ? AND type = 'إضافة'
  ''', [formattedDate]);

    // تحويل القيم إلى double مع التعامل مع القيم الفارغة
    final double totalPayments =
        (totalPaymentsResult.first['total_payments'] as num?)?.toDouble() ??
            0.0;
    final double totalAdditions =
        (totalAdditionsResult.first['total_additions'] as num?)?.toDouble() ??
            0.0;

    return {
      'total_payments': totalPayments,
      'total_additions': totalAdditions,
      'balance': totalPayments - totalAdditions,
    };
  }

// ================================================
/* Future<int> insertAgentOperation(
  int agentId,
  double amount,
  String details,
  String type,
  String date,
) async {
  final db = await database;
  return await db.insert('agent_operations', {
    'agent_id': agentId,
    'amount': amount,
    'details': details,
    'type': type,
    'date': date,
  });
}
 */

  Future<int> insertAgentOperation(
    int agentId,
    double amount,
    String details,
    String type,
  ) async {
    final db = await database;
    final date = DateFormat('yyyy-MM-dd HH:mm')
        .format(DateTime.now()); // إنشاء التاريخ هنا

    return await db.insert('agent_operations', {
      'agent_id': agentId,
      'amount': amount,
      'details': details,
      'type': type,
      'date': date, // استخدام التاريخ المنسق
    });
  }

  Future<List<Map<String, dynamic>>> getAllAgentOperations() async {
    final db = await database;
    return await db.query('agent_operations');
  }

// ================================================
  Future<List<String>> getAllCustomerNames() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('agents');
    return List.generate(maps.length, (i) => maps[i]['name'] as String);
  }
// ================================================
}

 */
