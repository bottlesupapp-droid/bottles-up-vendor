import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/database_debugger.dart';
import '../../../shared/widgets/responsive_wrapper.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  bool _isRunningHealthCheck = false;
  bool _isRunningVendorTest = false;
  DatabaseHealthReport? _healthReport;
  VendorCreationTest? _vendorTest;
  String _debugLog = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Database Debug'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearResults,
            tooltip: 'Clear Results',
          ),
        ],
      ),
      body: ResponsiveWrapper(
        centerContent: true,
        maxWidth: 800,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.bug_report,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Database Debug Tools',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Run diagnostics to identify and resolve database issues',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRunningHealthCheck ? null : _runHealthCheck,
                      icon: _isRunningHealthCheck 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.health_and_safety),
                      label: Text(_isRunningHealthCheck ? 'Running...' : 'Health Check'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRunningVendorTest ? null : _runVendorTest,
                      icon: _isRunningVendorTest 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.science),
                      label: Text(_isRunningVendorTest ? 'Running...' : 'Vendor Test'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Results Section
              if (_healthReport != null || _vendorTest != null) ...[
                Text(
                  'Diagnostic Results',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Health Report
                if (_healthReport != null) ...[
                  _buildHealthReportCard(theme),
                  const SizedBox(height: 16),
                ],
                
                // Vendor Test
                if (_vendorTest != null) ...[
                  _buildVendorTestCard(theme),
                  const SizedBox(height: 16),
                ],
              ],
              
              // Debug Log
              if (_debugLog.isNotEmpty) ...[
                Text(
                  'Debug Log',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Console Output',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _copyDebugLog,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _debugLog,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/database-setup'),
                      icon: const Icon(Icons.settings),
                      label: const Text('Database Setup'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/auth/login'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Login'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthReportCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _healthReport!.hasErrors 
              ? theme.colorScheme.error 
              : _healthReport!.hasWarnings 
                  ? theme.colorScheme.secondary 
                  : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _healthReport!.hasErrors 
                    ? Icons.error 
                    : _healthReport!.hasWarnings 
                        ? Icons.warning 
                        : Icons.check_circle,
                color: _healthReport!.hasErrors 
                    ? theme.colorScheme.error 
                    : _healthReport!.hasWarnings 
                        ? theme.colorScheme.secondary 
                        : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Database Health Report',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._healthReport!.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  item.status == HealthStatus.success 
                      ? Icons.check_circle 
                      : item.status == HealthStatus.warning 
                          ? Icons.warning 
                          : Icons.error,
                  size: 16,
                  color: item.status == HealthStatus.success 
                      ? theme.colorScheme.primary 
                      : item.status == HealthStatus.warning 
                          ? theme.colorScheme.secondary 
                          : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.category}: ${item.message}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildVendorTestCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _vendorTest!.isSuccessful 
              ? theme.colorScheme.primary 
              : theme.colorScheme.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _vendorTest!.isSuccessful ? Icons.check_circle : Icons.error,
                color: _vendorTest!.isSuccessful 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Vendor Creation Test',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._vendorTest!.results.map((result) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: result.success 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${result.step}: ${result.message}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _runHealthCheck() async {
    setState(() {
      _isRunningHealthCheck = true;
      _debugLog = '';
    });

    try {
      _addToDebugLog('🔍 Starting database health check...');
      final report = await DatabaseDebugger.checkDatabaseHealth();
      
      setState(() {
        _healthReport = report;
        _isRunningHealthCheck = false;
      });
      
      _addToDebugLog('✅ Health check completed');
      
    } catch (e) {
      setState(() {
        _isRunningHealthCheck = false;
      });
      _addToDebugLog('❌ Health check failed: $e');
    }
  }

  Future<void> _runVendorTest() async {
    setState(() {
      _isRunningVendorTest = true;
      _debugLog = '';
    });

    try {
      _addToDebugLog('🧪 Starting vendor creation test...');
      final test = await DatabaseDebugger.testVendorCreation();
      
      setState(() {
        _vendorTest = test;
        _isRunningVendorTest = false;
      });
      
      _addToDebugLog('✅ Vendor test completed');
      
    } catch (e) {
      setState(() {
        _isRunningVendorTest = false;
      });
      _addToDebugLog('❌ Vendor test failed: $e');
    }
  }

  void _addToDebugLog(String message) {
    setState(() {
      _debugLog += '${DateTime.now().toString().substring(11, 19)} $message\n';
    });
  }

  void _copyDebugLog() {
    Clipboard.setData(ClipboardData(text: _debugLog));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debug log copied to clipboard')),
    );
  }

  void _clearResults() {
    setState(() {
      _healthReport = null;
      _vendorTest = null;
      _debugLog = '';
    });
  }
}
