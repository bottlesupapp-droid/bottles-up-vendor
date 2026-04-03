import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class DatabaseDebugger {
  static final SupabaseClient _client = SupabaseConfig.client;

  /// Comprehensive database health check
  static Future<DatabaseHealthReport> checkDatabaseHealth() async {
    final report = DatabaseHealthReport();
    
    try {
      print('🔍 Starting database health check...');
      
      // Check connection
      await _checkConnection(report);
      
      // Check tables
      await _checkTables(report);
      
      // Check RLS policies
      await _checkRLSPolicies(report);
      
      // Check permissions
      await _checkPermissions(report);
      
      // Check auth setup
      await _checkAuthSetup(report);
      
      print('✅ Database health check completed');
      return report;
      
    } catch (e) {
      print('❌ Database health check failed: $e');
      report.addError('Health check failed', e.toString());
      return report;
    }
  }

  static Future<void> _checkConnection(DatabaseHealthReport report) async {
    try {
      print('🔌 Checking Supabase connection...');
      
      // Test basic connection
      await _client.from('auth.users').select('id').limit(1);
      report.addSuccess('Connection', 'Successfully connected to Supabase');
      
      // Check if we can access auth.users table
      report.addSuccess('Auth Table', 'auth.users table is accessible');
      
    } catch (e) {
      print('❌ Connection check failed: $e');
      report.addError('Connection', e.toString());
    }
  }

  static Future<void> _checkTables(DatabaseHealthReport report) async {
    final requiredTables = ['vendors', 'events', 'inventory', 'bookings'];
    
    for (final tableName in requiredTables) {
      try {
        print('📋 Checking table: $tableName');
        
        // Try to query the table
        await _client.from(tableName).select('*').limit(1);
        report.addSuccess('Table: $tableName', 'Table exists and is accessible');
        
      } catch (e) {
        print('❌ Table check failed for $tableName: $e');
        report.addError('Table: $tableName', e.toString());
      }
    }
  }

  static Future<void> _checkRLSPolicies(DatabaseHealthReport report) async {
    try {
      print('🔒 Checking RLS policies...');
      
      // Check if RLS is enabled on vendors table
      await _client.rpc('check_rls_policies');
      report.addSuccess('RLS Policies', 'RLS policies are properly configured');
      
    } catch (e) {
      print('❌ RLS check failed: $e');
      report.addError('RLS Policies', e.toString());
    }
  }

  static Future<void> _checkPermissions(DatabaseHealthReport report) async {
    try {
      print('🔑 Checking user permissions...');
      
      // Check if current user has proper permissions
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser != null) {
        report.addSuccess('User Auth', 'User is authenticated: ${currentUser.email}');
        
        // Try to access vendors table as authenticated user
        try {
          await _client.from('vendors').select('*').limit(1);
          report.addSuccess('User Permissions', 'User can access vendors table');
        } catch (e) {
          report.addError('User Permissions', 'Cannot access vendors table: $e');
        }
      } else {
        report.addWarning('User Auth', 'No authenticated user found');
      }
      
    } catch (e) {
      print('❌ Permissions check failed: $e');
      report.addError('User Permissions', e.toString());
    }
  }

  static Future<void> _checkAuthSetup(DatabaseHealthReport report) async {
    try {
      print('🔐 Checking auth setup...');
      
      // Check if auth is properly configured
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser != null) {
        report.addSuccess('Auth Configuration', 'Auth is properly configured - User: ${currentUser.email}');
      } else {
        report.addWarning('Auth Configuration', 'No authenticated user found');
      }
      
    } catch (e) {
      print('❌ Auth setup check failed: $e');
      report.addError('Auth Configuration', e.toString());
    }
  }

  /// Test vendor creation with detailed error reporting
  static Future<VendorCreationTest> testVendorCreation() async {
    final test = VendorCreationTest();
    
    try {
      print('🧪 Testing vendor creation...');
      
      // Create test vendor data
      final testVendor = {
        'id': 'test-vendor-${DateTime.now().millisecondsSinceEpoch}',
        'email': 'test@example.com',
        'name': 'Test Vendor',
        'business_name': 'Test Business',
        'phone_number': '+1234567890',
        'is_verified': true,
        'created_at': DateTime.now().toIso8601String(),
        'permissions': ['read_events', 'write_events'],
        'role': 'admin'
      };
      
      // Try to insert test vendor
      await _client.from('vendors').insert(testVendor);
      test.addSuccess('Insert', 'Successfully inserted test vendor');
      
             // Try to read the test vendor
       final result = await _client.from('vendors').select('*').eq('id', testVendor['id'] as String);
       if (result.isNotEmpty) {
         test.addSuccess('Read', 'Successfully read test vendor');
       } else {
         test.addError('Read', 'Could not read inserted vendor');
       }
       
       // Clean up test data
       await _client.from('vendors').delete().eq('id', testVendor['id'] as String);
      test.addSuccess('Cleanup', 'Successfully cleaned up test data');
      
    } catch (e) {
      print('❌ Vendor creation test failed: $e');
      test.addError('Test', e.toString());
    }
    
    return test;
  }

  /// Get detailed error information
  static Future<ErrorDetails> getErrorDetails(String error) async {
    final details = ErrorDetails(error);
    
    // Analyze common error patterns
    if (error.contains('relation "vendors" does not exist')) {
      details.addSolution('Create the vendors table using the SQL script');
      details.addSolution('Check if you have the correct database permissions');
    }
    
    if (error.contains('permission denied')) {
      details.addSolution('Check Row Level Security (RLS) policies');
      details.addSolution('Verify user authentication status');
      details.addSolution('Ensure proper table permissions');
    }
    
    if (error.contains('foreign key constraint')) {
      details.addSolution('Check if auth.users table exists');
      details.addSolution('Verify foreign key references');
    }
    
    if (error.contains('duplicate key')) {
      details.addSolution('User already exists - this is normal');
    }
    
    return details;
  }
}

class DatabaseHealthReport {
  final List<HealthCheckItem> _items = [];
  
  void addSuccess(String category, String message) {
    _items.add(HealthCheckItem(category, message, HealthStatus.success));
  }
  
  void addWarning(String category, String message) {
    _items.add(HealthCheckItem(category, message, HealthStatus.warning));
  }
  
  void addError(String category, String message) {
    _items.add(HealthCheckItem(category, message, HealthStatus.error));
  }
  
  List<HealthCheckItem> get items => _items;
  
  bool get hasErrors => _items.any((item) => item.status == HealthStatus.error);
  
  bool get hasWarnings => _items.any((item) => item.status == HealthStatus.warning);
  
  void printReport() {
    print('\n📊 DATABASE HEALTH REPORT');
    print('=' * 50);
    
    for (final item in _items) {
      final status = item.status == HealthStatus.success ? '✅' : 
                    item.status == HealthStatus.warning ? '⚠️' : '❌';
      print('$status ${item.category}: ${item.message}');
    }
    
    print('=' * 50);
    if (hasErrors) {
      print('❌ Database has errors that need to be fixed');
    } else if (hasWarnings) {
      print('⚠️ Database has warnings but should work');
    } else {
      print('✅ Database is healthy');
    }
  }
}

class HealthCheckItem {
  final String category;
  final String message;
  final HealthStatus status;
  
  HealthCheckItem(this.category, this.message, this.status);
}

enum HealthStatus { success, warning, error }

class VendorCreationTest {
  final List<TestResult> _results = [];
  
  void addSuccess(String step, String message) {
    _results.add(TestResult(step, message, true));
  }
  
  void addError(String step, String message) {
    _results.add(TestResult(step, message, false));
  }
  
  List<TestResult> get results => _results;
  
  bool get isSuccessful => _results.every((result) => result.success);
  
  void printResults() {
    print('\n🧪 VENDOR CREATION TEST RESULTS');
    print('=' * 40);
    
    for (final result in _results) {
      final status = result.success ? '✅' : '❌';
      print('$status ${result.step}: ${result.message}');
    }
    
    print('=' * 40);
    if (isSuccessful) {
      print('✅ Vendor creation test passed');
    } else {
      print('❌ Vendor creation test failed');
    }
  }
}

class TestResult {
  final String step;
  final String message;
  final bool success;
  
  TestResult(this.step, this.message, this.success);
}

class ErrorDetails {
  final String originalError;
  final List<String> solutions = [];
  
  ErrorDetails(this.originalError);
  
  void addSolution(String solution) {
    solutions.add(solution);
  }
  
  void printDetails() {
    print('\n🔍 ERROR ANALYSIS');
    print('=' * 30);
    print('Original Error: $originalError');
    print('\nPossible Solutions:');
    
    for (int i = 0; i < solutions.length; i++) {
      print('${i + 1}. ${solutions[i]}');
    }
  }
}
