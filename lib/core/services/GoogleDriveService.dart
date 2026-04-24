import 'dart:io';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  final List<String> scopes = ['email',gdrive.DriveApi.driveFileScope];
  final Map<String, Uint8List> _imageCache = {};
  late final GoogleSignIn _googleSignIn;

  // Use google_sign_in to handle user authentication
  GoogleDriveService() {
    _googleSignIn = GoogleSignIn(
      serverClientId: "117175444216-v40drl15ekah8q8gsrgc5ul035elq7rq.apps.googleusercontent.com",
      scopes: scopes,

    );
  }
// You can change this to whatever you want your app's folder to be named.
  static const _appFolderName = "Super_app";

  // A variable to cache the folder ID to avoid searching every time.
  String? _folderId;
  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;

  // Prompt the user to sign in
  Future<GoogleSignInAccount?> signIn() async {
    if (_currentUser != null) return _currentUser;
    _currentUser = await _googleSignIn.signIn();
    return _currentUser;
  }

  // Try to sign in without a user prompt on app start
  Future<void> signInSilently() async {
    _currentUser = await _googleSignIn.signInSilently();

  }

  Future<String?> getIdToken() async {
    final user = currentUser ?? await _googleSignIn.signInSilently();
    if (user == null) return null;
    final auth = await user.authentication;
    return auth.idToken;
  }

  // Sign out the current user
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  // Get an authenticated client based on the signed-in user
  Future<http.Client?> getAuthenticatedClient() async {
    if (_currentUser == null) {
      await signIn();
    }
    if (_currentUser == null) return null; // User cancelled sign-in

    final authHeaders = await _currentUser!.authHeaders;
    return authenticatedClient(
      http.Client(),
      AccessCredentials(
        AccessToken(
          'Bearer',
          authHeaders['Authorization']!.substring(7),
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        null, // No refresh token
        scopes,
      ),
    );
  }


  /// Finds the app folder ID, or creates it if it doesn't exist.
  Future<String?> _getFolderId(gdrive.DriveApi driveApi) async {
    // Return the cached ID if we already have it.
    if (_folderId != null) return _folderId;

    try {
      // Search for a folder with the specific name in the user's root directory.
      final response = await driveApi.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and name='$_appFolderName' and 'root' in parents and trashed=false",
        $fields: "files(id, name)",
      );

      if (response.files != null && response.files!.isNotEmpty) {
        // Folder exists, cache and return its ID.
        _folderId = response.files!.first.id;
        return _folderId;
      } else {
        // Folder doesn't exist, so create it.
        final gdrive.File folder = gdrive.File()
          ..name = _appFolderName
          ..mimeType = 'application/vnd.google-apps.folder';

        final createdFolder = await driveApi.files.create(folder);
        _folderId = createdFolder.id;
        return _folderId;
      }
    } catch (e) {
      print("Error finding/creating folder: $e");
      return null;
    }
  }

  // Uploads a file to the signed-in user's Google Drive
  Future<String?> uploadFile(File file, String fileName , String filetype, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final client = await getAuthenticatedClient();
      if (client == null) throw Exception('Authentication failed.');

      final driveApi = gdrive.DriveApi(client);
      final folderId = await _getFolderId(driveApi);
      if (folderId == null) throw Exception('Could not find or create app folder.');

      final gdrive.File fileToUpload = gdrive.File()
        ..name = fileName
        ..parents = [folderId];

      final createdFile = await driveApi.files.create(
        fileToUpload,
        uploadMedia: gdrive.Media(file.openRead(), file.lengthSync()),
      );

      for (var i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100)); // Simulate network latency
        if (onProgress != null) {
          onProgress(i / 10.0); // Report progress from 0.1 to 1.0
        }
      }
      // CRITICAL: Make the file public so others can view it
      await driveApi.permissions.create(
        gdrive.Permission(role: 'reader', type: 'anyone'),
        createdFile.id!,
      );

      if(filetype == 'image')
        {
          final fileWithLink = await driveApi.files.get(
            createdFile.id!,
            $fields:'webViewLink',
          ) as gdrive.File;

          return fileWithLink.webViewLink;
        }
      if(filetype == 'audio')
        {
          final directDownloadLink = 'https://drive.google.com/uc?export=download&id=${createdFile.id!}';

          return directDownloadLink;
        }
      return null;
    } catch (e) {
      print('Error uploading to Google Drive: $e');
      return null;
    }
  }

  // downloadFile remains mostly the same but uses the user's auth
  Future<Uint8List?> downloadFile(String fileId) async {
    if (fileId.isEmpty) return null;

    // 1. In-memory cache — instant hit for already-downloaded images.
    if (_imageCache.containsKey(fileId)) {
      return _imageCache[fileId];
    }

    try {
      // 2. Construct the direct public download URL.
      final downloadUrl = 'https://drive.google.com/uc?export=download&id=$fileId';
      final uri = Uri.parse(downloadUrl);

      // 3. Unauthenticated GET with a 15-second timeout so a slow / hung
      //    Google Drive response never blocks the UI indefinitely.
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Reject HTML responses — Google Drive returns a warning/confirmation
        // page (instead of raw bytes) for files that need virus-scan consent.
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('text/html')) {
          print('Drive returned HTML for $fileId (virus-scan gate or bad ID)');
          return null;
        }

        final downloadedData = response.bodyBytes;
        _imageCache[fileId] = downloadedData;
        return downloadedData;
      } else {
        print('Error downloading file: Status code ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // Covers TimeoutException and any network error.
      print('Error downloading from Google Drive ($fileId): $e');
      return null;
    }
  }
}