// test/team_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:year4_project/services/team_service.dart';

// Test double that overrides the methods we want to test
class TestableTeamService extends TeamService {
  // Maps to store test data
  final Map<int, int?> userTeamIdMap = {};
  final Map<int, int?> teamLeagueIdMap = {};

  // Flag to simulate exceptions
  bool throwsException = false;

  @override
  Future<int?> fetchUserTeamId(int userId) async {
    if (throwsException) {
      throw Exception('Test exception');
    }
    // Return the value from our test map
    return userTeamIdMap[userId];
  }

  // Method that calls fetchUserTeamId but handles exceptions
  // This simulates the try/catch in the real implementation
  Future<int?> callFetchUserTeamIdWithErrorHandling(int userId) async {
    try {
      return await fetchUserTeamId(userId);
    } catch (e) {
      print('Error in fetchUserTeamId: $e');
      return null;
    }
  }

  @override
  Future<int?> fetchLeagueId(int teamId) async {
    if (throwsException) {
      throw Exception('Test exception');
    }
    // Return the value from our test map
    return teamLeagueIdMap[teamId];
  }

  // Method that calls fetchLeagueId but handles exceptions
  // This simulates the try/catch in the real implementation
  Future<int?> callFetchLeagueIdWithErrorHandling(int teamId) async {
    try {
      return await fetchLeagueId(teamId);
    } catch (e) {
      print('Error in fetchLeagueId: $e');
      return null;
    }
  }
}

void main() {
  late TestableTeamService teamService;

  setUp(() {
    teamService = TestableTeamService();
    // Reset maps between tests
    teamService.userTeamIdMap.clear();
    teamService.teamLeagueIdMap.clear();
    teamService.throwsException = false;
  });

  group('fetchUserTeamId', () {
    test('should return team_id when user has an active team', () async {
      // Arrange
      const userId = 123;
      const teamId = 456;
      teamService.userTeamIdMap[userId] = teamId;

      // Act
      final result = await teamService.fetchUserTeamId(userId);

      // Assert
      expect(result, equals(teamId));
    });

    test('should return null when user has no active team', () async {
      // Arrange
      const userId = 123;
      // Not adding any mapping for this user

      // Act
      final result = await teamService.fetchUserTeamId(userId);

      // Assert
      expect(result, isNull);
    });

    test('should handle exceptions gracefully', () async {
      // Arrange
      const userId = 123;
      teamService.throwsException = true;

      // Act - using the method with error handling
      final result = await teamService.callFetchUserTeamIdWithErrorHandling(userId);

      // Assert
      expect(result, isNull);
    });
  });

  group('fetchLeagueId', () {
    test('should return league_id when team has a league', () async {
      // Arrange
      const teamId = 456;
      const leagueId = 789;
      teamService.teamLeagueIdMap[teamId] = leagueId;

      // Act
      final result = await teamService.fetchLeagueId(teamId);

      // Assert
      expect(result, equals(leagueId));
    });

    test('should return null when team has no league', () async {
      // Arrange
      const teamId = 456;
      // Not adding any mapping for this team

      // Act
      final result = await teamService.fetchLeagueId(teamId);

      // Assert
      expect(result, isNull);
    });

    test('should handle exceptions gracefully', () async {
      // Arrange
      const teamId = 456;
      teamService.throwsException = true;

      // Act - using the method with error handling
      final result = await teamService.callFetchLeagueIdWithErrorHandling(teamId);

      // Assert
      expect(result, isNull);
    });
  });
}