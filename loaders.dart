import 'dart:io';
import './utils.dart' as utils;
import 'userdata.dart' as userdata;
import 'utils.dart' show JsonExtension;

const _loaders = <String, Future<void> Function(String)>{
  'yandex': _loadWithYandex
};
final _modsPath = utils.combinePath([userdata.minecraftPath, 'mods']);

Future<void> loadWith(String loader, String link) async {
  final dir = Directory(_modsPath);
  dir.deleteSync(recursive: true);
  dir.create();
  await _loaders[loader]?.call(link);
}

Future<void> _loadWithYandex(String link) async {
  const YANDEX_URL = 'https://cloud-api.yandex.net/v1/disk/public/resources';
  const CHUNK_SIZE = 16;

  final client = HttpClient();

  Future<Map<String, dynamic>> yandexJson(int limit, {int offset = 0}) async {
    return utils.HttpGetJson(
        client,
        utils.addApiAttributes(YANDEX_URL, [
          ('public_key', link),
          ('limit', limit.toString()),
          ('offset', offset.toString())
        ]));
  }

  var data = await yandexJson(0);
  var total = data.getSubtree('_embedded').getProperty<int>('total');
  var chunks = total / CHUNK_SIZE + 1;
  var tasks = <Future<void>>[];
  for (int _ = 0; _ < chunks; _++) {
    data = await yandexJson(CHUNK_SIZE, offset: _ * CHUNK_SIZE);
    final files = data.getSubtree('_embedded').getSubgarden('items');

    for (var file in files) {
      if (file.getProperty<String>('type') != 'file') continue;
      final name = file.getProperty<String>('name');

      tasks.add(client
          .getUrl(Uri.parse(file.getProperty<String>('file')))
          .then((request) => request.close())
          .then((response) => response
              .pipe(File(utils.combinePath([_modsPath, name])).openWrite()))
          .then((x) => print(name)));
    }
  }
}
