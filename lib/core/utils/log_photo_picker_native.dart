import 'package:image_picker/image_picker.dart';

Future<List<XFile>> pickLogPhotos(ImageSource source) async {
  final picker = ImagePicker();
  if (source == ImageSource.camera) {
    final photo = await picker.pickImage(source: source);
    return photo == null ? [] : [photo];
  }
  return picker.pickMultiImage();
}
