import 'dart:async';
import 'dart:html' as html;

Future<String?> pickFriendPhotoDataUrl() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..style.display = 'none';

  html.document.body?.append(input);

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;

    if (file == null) {
      input.remove();
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      input.remove();
      completer.complete(reader.result as String?);
    });
    reader.onError.first.then((_) {
      input.remove();
      completer.complete(null);
    });
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}
