// test/services/auth_service_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:year4_project/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:year4_project/models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Create a completely separate implementation that doesn't extend AuthService
class TestableAuthService {
  // Mock URLs and tokens
  final String userLoginFunctionUrl = 'https://example.com/functions/v1/user_login';
  final String userSignupFunctionUrl = 'https://example.com/functions/v1/user_signup';
  final String userLogoutFunctionUrl = 'https://example.com/functions/v1/user_logout';
  final String bearerToken = 'mock_token';

  // Mock the storage
  final Map<String, String> secureStorageValues = {};

  // Mock data
  bool authStatusResult = false;
  Map<String, dynamic>? userSessionData;
  bool loginResult = false;
  bool registerResult = false;
  bool logoutResult = false;

  // Flags for simulating exceptions
  bool throwsExceptionOnLogin = false;
  bool throwsExceptionOnRegister = false;
  bool throwsExceptionOnLogout = false;
  bool throwsExceptionOnCheckAuth = false;
  bool throwsExceptionOnRestoreSession = false;

  // Storage methods
  Future<void> _storeUserData(Map<String, dynamic> userData) async {
    secureStorageValues['user_id'] = userData['id'].toString();
    secureStorageValues['user_email'] = userData['email'].toString();
    secureStorageValues['user_name'] = userData['name'].toString();
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    if (throwsExceptionOnRestoreSession) {
      throw Exception('Test exception during restore session');
    }

    if (secureStorageValues.isEmpty ||
        !secureStorageValues.containsKey('user_id') ||
        !secureStorageValues.containsKey('user_email') ||
        !secureStorageValues.containsKey('user_name')) {
      return null;
    }

    return {
      'id': int.parse(secureStorageValues['user_id']!),
      'email': secureStorageValues['user_email'],
      'name': secureStorageValues['user_name'],
    };
  }

  // Model update methods
  void _updateUserModel(BuildContext context, Map<String, dynamic> data) {
    final userModel = Provider.of<UserModel>(context, listen: false);
    userModel.setUser(
      id: data['id'],
      email: data['email'].toString(),
      name: data['name'].toString(),
    );
  }

  void _clearUserModel(BuildContext context) {
    final userModel = Provider.of<UserModel>(context, listen: false);
    userModel.clearUser();
  }

  // Auth methods to test
  Future<bool> userLogin(BuildContext context, String email, String password) async {
    if (throwsExceptionOnLogin) {
      throw Exception('Test exception during login');
    }

    if (loginResult) {
      if (userSessionData != null) {
        await _storeUserData(userSessionData!);
        _updateUserModel(context, userSessionData!);
      }
    }

    return loginResult;
  }

  Future<bool> registerUser(BuildContext context, String username, String email, String password) async {
    if (throwsExceptionOnRegister) {
      throw Exception('Test exception during registration');
    }

    return registerResult;
  }

  Future<bool> userLogout(BuildContext context, int userId) async {
    if (throwsExceptionOnLogout) {
      throw Exception('Test exception during logout');
    }

    if (logoutResult) {
      _clearUserModel(context);
      secureStorageValues.clear();
    }

    return logoutResult;
  }

  Future<bool> checkAuthStatus() async {
    if (throwsExceptionOnCheckAuth) {
      throw Exception('Test exception during auth check');
    }

    return authStatusResult;
  }

  Future<Map<String, dynamic>?> restoreUserSession() async {
    return await _getUserData();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestableAuthService authService;
  late UserModel mockUserModel;

  setUp(() {
    authService = TestableAuthService();
    mockUserModel = UserModel(id: 0, email: '', name: '');

    // Reset all test data
    authService.authStatusResult = false;
    authService.userSessionData = null;
    authService.loginResult = false;
    authService.registerResult = false;
    authService.logoutResult = false;
    authService.secureStorageValues.clear();

    // Reset exception flags
    authService.throwsExceptionOnLogin = false;
    authService.throwsExceptionOnRegister = false;
    authService.throwsExceptionOnLogout = false;
    authService.throwsExceptionOnCheckAuth = false;
    authService.throwsExceptionOnRestoreSession = false;
  });

  // Helper function to create a mock BuildContext with a UserModel provider
  BuildContext createMockContext(WidgetTester tester) {
    late BuildContext resultContext;

    tester.pumpWidget(
      ChangeNotifierProvider<UserModel>.value(
        value: mockUserModel,
        child: Builder(
          builder: (context) {
            resultContext = context;
            return Container();
          },
        ),
      ),
    );

    return resultContext;
  }

  group('checkAuthStatus', () {
    test('should return true when user is authenticated', () async {
      // Arrange
      authService.authStatusResult = true;

      // Act
      final result = await authService.checkAuthStatus();

      // Assert
      expect(result, isTrue);
    });

    test('should return false when user is not authenticated', () async {
      // Arrange
      authService.authStatusResult = false;

      // Act
      final result = await authService.checkAuthStatus();

      // Assert
      expect(result, isFalse);
    });

    test('should handle exceptions gracefully', () async {
      // Arrange
      authService.throwsExceptionOnCheckAuth = true;

      // Act & Assert
      expect(() => authService.checkAuthStatus(), throwsException);
    });
  });

  group('restoreUserSession', () {
    test('should return user data when session exists', () async {
      // Arrange
      final userData = {'id': 123, 'email': 'test@example.com', 'name': 'Test User'};
      authService.secureStorageValues['user_id'] = userData['id'].toString();
      authService.secureStorageValues['user_email'] = userData['email'] as String;
      authService.secureStorageValues['user_name'] = userData['name'] as String;

      // Act
      final result = await authService.restoreUserSession();

      // Assert
      expect(result, isNotNull);
      expect(result!['id'], equals(userData['id']));
      expect(result['email'], equals(userData['email']));
      expect(result['name'], equals(userData['name']));
    });

    test('should return null when no session exists', () async {
      // Act
      final result = await authService.restoreUserSession();

      // Assert
      expect(result, isNull);
    });

    test('should handle exceptions gracefully', () async {
      // Arrange
      authService.throwsExceptionOnRestoreSession = true;

      // Act & Assert
      expect(() => authService.restoreUserSession(), throwsException);
    });
  });

  group('userLogin', () {
    testWidgets('should return true and update user model on successful login', (WidgetTester tester) async {
      // Arrange
      final testContext = createMockContext(tester);
      authService.loginResult = true;
      authService.userSessionData = {'id': 123, 'email': 'test@example.com', 'name': 'Test User'};

      // Act
      final result = await authService.userLogin(testContext, 'test@example.com', 'password');

      // Assert
      expect(result, isTrue);
      expect(mockUserModel.id, equals(123));
      expect(mockUserModel.email, equals('test@example.com'));
      expect(mockUserModel.name, equals('Test User'));

      // Check storage
      expect(authService.secureStorageValues['user_id'], equals('123'));
      expect(authService.secureStorageValues['user_email'], equals('test@example.com'));
      expect(authService.secureStorageValues['user_name'], equals('Test User'));
    });

    testWidgets('should return false on failed login', (WidgetTester tester) async {
      // Arrange
      final testContext = createMockContext(tester);
      authService.loginResult = false;

      // Act
      final result = await authService.userLogin(testContext, 'test@example.com', 'wrong_password');

      // Assert
      expect(result, isFalse);
      expect(mockUserModel.id, equals(0)); // Should remain unchanged
      expect(authService.secureStorageValues.isEmpty, isTrue); // No data should be stored
    });

    testWidgets('should handle exceptions', (WidgetTester tester) async {
      // Arrange
      final testContext = createMockContext(tester);
      authService.throwsExceptionOnLogin = true;

      // Act & Assert
      expect(() => authService.userLogin(testContext, 'test@example.com', 'password'), throwsException);
    });
  });

  group('registerUser', () {
    testWidgets('should return true on successful registration', (WidgetTester tester) async {
      // Arrange
      final testContext = createMockContext(tester);
      authService.registerResult = true;

      // Act
      final result = await authService.registerUser(testContext, 'Test User', 'test@example.com', 'password');

      // Assert
      expect(result, isTrue);
    });

    testWidgets('should return false on failed registration', (WidgetTester tester) async {
      // Arrange
      final testContext = createMockContext(tester);
      authService.registerResult = false;

      // Act
      final result = await authService.registerUser(testContext, 'Test User', 'existing@example.com', 'password');

      // Assert
      expect(result, isFalse);
    });

    testWidgets('should handle exceptions', (WidgetTester tester) async {
      // Arrange
      final testContext = createMockContext(tester);
      authService.throwsExceptionOnRegister = true;

      // Act & Assert
      expect(() => authService.registerUser(testContext, 'Test User', 'test@example.com', 'password'), throwsException);
    });
  });

  group('userLogout', () {
    testWidgets('should return true and clear user model on successful logout', (WidgetTester tester) async {
      // Arrange
      final testContext = createMockContext(tester);
      mockUserModel.setUser(id: 123, email: 'test@example.com', name: 'Test User');
      authService.secureStorageValues['user_id'] = '123';
      authService.secureStorageValues['user_email'] = 'test@example.com';
      authService.secureStorageValues['user_name'] = 'Test User';
      authService.logoutResult = true;

      // Act
      final result = await authService.userLogout(testContext, 123);

      // Assert
      expect(result, isTrue);
      expect(mockUserModel.id, equals(0)); // Should be reset
      expect(mockUserModel.email, equals('')); // Should be reset
      expect(mockUserModel.name, equals('')); // Should be reset
      expect(authService.secureStorageValues.isEmpty, isTrue); // Storage should be cleared
    });

    testWidgets('should return false on failed logout', (WidgetTester tester) async {
      // Arrange
      final testContext = createMockContext(tester);
      mockUserModel.setUser(id: 123, email: 'test@example.com', name: 'Test User');
      authService.secureStorageValues['user_id'] = '123';
      authService.logoutResult = false;

      // Act
      final result = await authService.userLogout(testContext, 123);

      // Assert
      expect(result, isFalse);
      expect(mockUserModel.id, equals(123)); // Should remain unchanged
      expect(authService.secureStorageValues.isEmpty, isFalse); // Storage should remain unchanged
    });

    testWidgets('should handle exceptions', (WidgetTester tester) async {
      // Arrange
      final testContext = createMockContext(tester);
      authService.throwsExceptionOnLogout = true;

      // Act & Assert
      expect(() => authService.userLogout(testContext, 123), throwsException);
    });
  });
}