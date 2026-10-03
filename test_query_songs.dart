import 'package:on_audio_query/on_audio_query.dart';

void main() {
  final query = OnAudioQuery();
  query.querySongs(
    sortType: SongSortType.TITLE,
    orderType: OrderType.ASC_OR_SMALLER,
    uriType: UriType.EXTERNAL,
    ignoreCase: true,
    path: '/path/to/folder',
  );
}
