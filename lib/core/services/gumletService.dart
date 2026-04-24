import 'dart:convert';
import 'package:dio/dio.dart';

final dio = Dio();
Future<String?> uploadVoiceNoteGumlet(String voiceUrl) async {
  try{
    Response response = await dio.post(
        'https://api.gumlet.com/v1/video/assets',
        options: Options(
          headers: {
            "Authorization": "Bearer gumlet_4095f90b95d2ab9d5ffe513b4c22303e",
            "Content-Type": "application/json"
          },
        ),
        data: {
          "input": voiceUrl,
          "collection_id": "68a339859deb1fdadc26d09b",
          'format': 'MP4', // Since it's audio, MP4 is a good choice.
          'audio_only': true, // This flag is crucial for voice notes
          'title': 'Voice Note ${DateTime.now().millisecondsSinceEpoch}',
        });
    if(response.statusCode ==  200 || response.statusCode == 201)
      {
        print(response.data);
        return response.data['output']['playback_url'] as String?;
      }
  } on DioException catch (e){
    print('DioException in uploadVoiceNoteGumlet: $e');
  } catch (e) {
    print('Error uploading to Gumlet: $e');
  }
  return null;
  }
